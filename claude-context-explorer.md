# Codebase Exploration: REDCap → HealthLake FHIR R4 Pipeline

Exploration date: 2026-09-28

---

## 1. Overall Architecture and Purpose

The system is a proof-of-concept clinical data pipeline for New Zealand health registries.
It ingests REDCap CSV exports and loads them into Amazon HealthLake as FHIR R4 resources.

Three clinical registries are implemented: `ovarian_cancer`, `cardiac_surgery`, and `heartland_hf`
(HEARTLAND Heart Failure Registry — a US dataset used as a REDCap repeating-instruments demo).

The pipeline is entirely event-driven. No polling loops exist outside of the Step Functions
wait/poll construct for the asynchronous HealthLake import job.

### Module breakdown

| Module | Path | Purpose |
|---|---|---|
| bootstrap | `/workspace/active_repo/bootstrap/` | One-time: encrypted S3 tfstate bucket + DynamoDB lock table |
| security | `/workspace/active_repo/modules/security/` | KMS CMK (main), CloudTrail trail + S3 bucket |
| ingestion | `/workspace/active_repo/modules/ingestion/` | Landing S3 bucket, redcap_exporter Lambda, EventBridge Scheduler |
| persistence | `/workspace/active_repo/modules/persistence/` | HealthLake FHIR R4 datastore (awscc provider), fhir_export bucket, import_output bucket, dedicated HealthLake KMS key, HealthLake IAM data-access role |
| transformation | `/workspace/active_repo/modules/transformation/` | fhir_staging S3 bucket, csv_to_fhir_mapper + import_launcher + import_poller Lambdas, Step Functions state machine, EventBridge rule, SNS failure topic, SQS Lambda DLQ |
| networking | `/workspace/active_repo/modules/networking/` | VPC skeleton with private/public subnets, interface endpoints for all services used by the pipeline, VPC flow logs. NOT wired to any Lambda in the POC — available for production. |

### Environment structure

`environments/dev/main.tf` is the root module that wires the four active modules together.
`environments/prod/` mirrors this structure. Provider versions: `aws ~> 5.80`, `awscc ~> 1.9`,
Terraform `~> 1.6`.

---

## 2. Step Functions — the Orchestration Layer

Step Functions is the **sole orchestration mechanism** for the transformation pipeline. It is
implemented as a STANDARD type state machine named `{project}-{env}-import-orchestrator`.

### State machine definition (inline in Terraform HCL)

Defined in: `/workspace/active_repo/modules/transformation/main.tf` (lines 261–388)

States in execution order:

```
MapCSVToFHIR        Task — invokes csv_to_fhir_mapper Lambda
  └─► LaunchImportJob   Task — invokes import_launcher Lambda
        └─► WaitForImport    Wait — 60 seconds (no Lambda, no cost)
              └─► PollImportStatus   Task — invokes import_poller Lambda
                    └─► CheckImportStatus   Choice
                          ├─ COMPLETED → ImportComplete   (Succeed)
                          ├─ FAILED   → NotifyFailure     (Task: sns:Publish)
                          │                └─► ImportFailed (Fail)
                          └─ default  → WaitForImport (loop)
```

Key design decisions baked into the state machine:
- All file content moves through S3, never through SFN state. SFN only passes metadata
  (bucket names, S3 keys, job IDs). The 256 KB SFN I/O limit is nowhere near being reached.
- The SFN execution input is the **raw EventBridge S3 event object** (`Payload.$: "$"`).
- `NotifyFailure` calls `arn:aws:states:::sns:publish` directly (SDK integration) — no
  extra Lambda required for alerting.
- Retry logic on Lambda task states: up to 3 attempts, 2-second initial interval,
  BackoffRate 2, on Lambda service/throttling errors.
- `Catch: States.ALL` on every Task state routes all unhandled exceptions to `NotifyFailure`.
- `ClientToken` in the import_launcher is derived from `MD5(fhir_key)` — makes SFN retries
  idempotent against HealthLake.

### IAM for Step Functions

Defined in: `/workspace/active_repo/modules/transformation/iam.tf` (lines 195–291)

- SFN execution role: `states.amazonaws.com` trust, scoped `lambda:InvokeFunction` on the
  three Lambda ARNs, `sns:Publish` on the failure topic, KMS decrypt/generate, CloudWatch Logs.
- EventBridge-to-SFN role: `events.amazonaws.com` trust, `states:StartExecution` on the
  state machine ARN only.

### No alternative orchestration tools present

There are no references to:
- EventBridge Pipes
- Lambda-chaining (one Lambda invoking another)
- SQS-triggered Lambda chains
- ECS tasks / Fargate
- AWS Glue / Batch
- Apache Airflow / MWAA
- Step Functions Express workflows

---

## 3. Data Pipeline Flow — Service Trigger Chain

### Nightly scheduled ingestion (production path)

```
EventBridge Scheduler (cron 0 2 * * ? *)
  → invokes redcap_exporter Lambda
      → calls REDCap API (urllib POST to /api/index.php)
      → writes CSV to s3://landing-bucket/redcap-exports/{YYYY}/{MM}/{DD}/{HHMMSS}-{project_id}.csv
      → S3 Object Created event published to EventBridge default bus
          → EventBridge rule (source=aws.s3, key prefix=redcap-exports/)
              → starts Step Functions execution (full state machine as above)
```

### Simulation path

```
simulate/inject.sh uploads CSV to s3://landing-bucket/redcap-exports/{registry}/{timestamp}-sim.csv
  → same EventBridge → SFN chain as above
```

### Detailed per-Lambda behaviour

**redcap_exporter** (`/workspace/active_repo/modules/ingestion/lambda/redcap_exporter/handler.py`)
- Reads REDCap API token from Secrets Manager
- POSTs to REDCap `/api/index.php` with `content=record`, `format=csv`, `type=flat`
- Writes to landing bucket with KMS SSE
- On failure: SQS DLQ (`maximum_retry_attempts = 0`, no async retry)

**csv_to_fhir_mapper** (`/workspace/active_repo/modules/transformation/lambda/csv_to_fhir_mapper/handler.py`)
- Receives the full EventBridge S3 event as input
- Detects registry via `_detect_registry(key)`:
  - Simulation: checks `key.split("/")[1]` against `_KNOWN` frozenset
  - Production: matches filename suffix `*-{project_id}.csv` against `REGISTRY_MAP` env var
- Downloads entire CSV into memory (`obj["Body"].read().decode("utf-8-sig")`)
- Dispatches to per-registry `map_row(row: dict) -> list` function
- Serialises all FHIR resources to NDJSON in memory (5–10x expansion from CSV)
- Writes to `s3://fhir-staging/fhir-ndjson/{registry}/{YYYY}/{MM}/{DD}/{HHMMSS}.ndjson`
- Returns metadata dict to SFN (bucket name, key, resource_count, skipped_rows, registry)
- **Known memory constraint**: 256 MB allocated, ~150–200 MB usable. Binding limit is ~20–40 MB CSV input.
- Timeout: 300 seconds
- Concurrency: `reserved_concurrent_executions = 5`

**import_launcher** (`/workspace/active_repo/modules/transformation/lambda/import_launcher/handler.py`)
- Receives mapper metadata (fhir_bucket, fhir_key, registry)
- Calls `healthlake.start_fhir_import_job` — plain NDJSON import (no DTA)
- Job output written to `s3://import-output-bucket/import-output/` with KMS key
- Returns `{job_id, fhir_key, registry}`
- Timeout: 60 seconds, `reserved_concurrent_executions = 10`

**import_poller** (`/workspace/active_repo/modules/transformation/lambda/import_poller/handler.py`)
- Calls `healthlake.describe_fhir_import_job`
- Returns `{job_id, status, registry}` — status is one of SUBMITTED, IN_PROGRESS, COMPLETED, FAILED
- Timeout: 30 seconds

### S3 bucket inventory

| Bucket | Purpose | Lifecycle | Object Lock |
|---|---|---|---|
| `landing` | REDCap CSV drop zone | - | COMPLIANCE, 1 year |
| `fhir_staging` | NDJSON between mapper and HealthLake | expire after 14 days | None |
| `fhir_export` | HealthLake bulk export target | - | GOVERNANCE, 1 year |
| `import_output` | HealthLake import job provenance output | - | GOVERNANCE, 1 year |
| `cloudtrail` | CloudTrail audit logs | - | GOVERNANCE, 365 days |

---

## 4. Infrastructure-as-Code: Terraform Files

All IaC is Terraform (no CDK, no CloudFormation, no SAM).

### Root modules

| File | Purpose |
|---|---|
| `/workspace/active_repo/environments/dev/main.tf` | Dev environment — wires all four modules |
| `/workspace/active_repo/environments/dev/versions.tf` | Provider pinning (aws ~> 5.80, awscc ~> 1.9), S3 backend config |
| `/workspace/active_repo/environments/dev/variables.tf` | aws_region, project_name, redcap_url, redcap_project_id, export_schedule_expression, registry_map |
| `/workspace/active_repo/environments/dev/outputs.tf` | landing_bucket_name, healthlake_datastore_id/endpoint, fhir_staging_bucket_name, import_orchestrator_sfn_arn, import_failures_sns_arn |
| `/workspace/active_repo/environments/prod/` | Mirrors dev |
| `/workspace/active_repo/bootstrap/main.tf` | tfstate S3 bucket + KMS + DynamoDB lock table |

### Module Terraform files

| File | Key resources |
|---|---|
| `/workspace/active_repo/modules/security/main.tf` | `aws_kms_key.main` (clinical CMK), `aws_cloudtrail.main` |
| `/workspace/active_repo/modules/ingestion/main.tf` | `aws_s3_bucket.landing`, `aws_s3_bucket_notification.landing` (eventbridge=true), `aws_lambda_function.redcap_exporter`, `aws_scheduler_schedule.redcap_export` |
| `/workspace/active_repo/modules/ingestion/iam.tf` | IAM roles for redcap_exporter Lambda and EventBridge Scheduler |
| `/workspace/active_repo/modules/persistence/main.tf` | `awscc_healthlake_fhir_datastore.main` (R4), `aws_kms_key.healthlake`, `aws_s3_bucket.fhir_export`, `aws_s3_bucket.import_output` |
| `/workspace/active_repo/modules/persistence/iam.tf` | `aws_iam_role.healthlake_data_access` (assumed by HealthLake during imports), `aws_iam_role.healthlake_export` |
| `/workspace/active_repo/modules/transformation/main.tf` | `aws_s3_bucket.fhir_staging`, `aws_sns_topic.import_failures`, `aws_sqs_queue.lambda_dlq`, three `aws_lambda_function` resources, `aws_cloudwatch_event_rule.s3_landing_csv`, `aws_cloudwatch_event_target.sfn`, `aws_sfn_state_machine.import_orchestrator` |
| `/workspace/active_repo/modules/transformation/iam.tf` | IAM roles for csv_to_fhir_mapper, import_launcher, import_poller Lambdas; SFN execution role; EventBridge-to-SFN role; HealthLake fhir_staging read policy |
| `/workspace/active_repo/modules/networking/main.tf` | VPC, subnets, IGW, NAT (optional), security groups, VPC flow logs, interface endpoints for secretsmanager/lambda/states/kms/logs/monitoring/healthlake/sns/sqs, gateway endpoints for S3 and DynamoDB |

### Notable Terraform patterns

- HealthLake datastore uses the `awscc` (CloudFormation-backed) provider because the
  native `aws` provider does not support `awscc_healthlake_fhir_datastore`. All other
  resources use the standard `aws` provider.
- `prevent_destroy = true` on: HealthLake datastore, both KMS CMKs, landing/fhir_export/
  import_output S3 buckets, CloudTrail bucket, tfstate bucket and DynamoDB table.
- Lambda archives are created by `data "archive_file"` blocks inline in Terraform — no
  separate CI/CD build step needed for POC.
- All Lambdas target `arm64` / Python 3.12.

---

## 5. Supplementary Documents

| File | Content |
|---|---|
| `/workspace/active_repo/pipeline-flow.md` | Step-by-step trace with code line references for each pipeline stage |
| `/workspace/active_repo/sm-input-size-constraints.md` | Layer-by-layer size limit analysis; identifies Lambda memory (256 MB) as the binding constraint, not SFN I/O (256 KB) |
| `/workspace/active_repo/dta-findings.md` | Research on HealthLake Data Transformation Agent (DTA) — still Preview as of Sep 2026; supports CSV; 100-column hard limit; unknown pricing; `concurrent transformation jobs = 1` per account |

---

## 6. Key Facts for Step Functions vs Alternatives Comparison

### Why Step Functions was chosen (inferred from code)

1. **Wait loop with no Lambda cost**: The `WaitForImport` state (60-second pause) is a native
   SFN Wait state. Under Lambda chaining, you would need a timed retry mechanism — either
   EventBridge rules per execution, or a recursive Lambda that re-invokes itself with delay,
   neither of which is as clean.

2. **Retry and catch at the orchestration layer**: Each Task state has structured `Retry` and
   `Catch` blocks. Under Lambda chaining, retry/error handling logic would be scattered across
   each Lambda's own code.

3. **Centralised execution history**: SFN's execution console shows the full event trace per
   CSV file, which is valuable for audit in a clinical-data context.

4. **Direct SNS SDK integration**: `NotifyFailure` uses `arn:aws:states:::sns:publish` without
   needing a Lambda wrapper. This is a SFN-specific capability.

5. **State preserved across the wait loop**: The job_id from import_launcher is held in SFN
   state and passed directly to import_poller without any external store.

### Constraints and limitations noted in the codebase

- The SFN state machine type is STANDARD (not EXPRESS). STANDARD executions have a 1-year
  maximum duration, support exactly-once semantics, and have per-state-transition pricing
  ($0.025/1000 state transitions). For this batch pipeline running nightly, this is appropriate.
- The 256 KB SFN input/output limit is explicitly called out in `sm-input-size-constraints.md`
  as NOT a practical concern because only metadata flows through SFN boundaries.
- The state machine definition is inlined as a Terraform `jsonencode()` block — there is no
  separate ASL JSON file or CDK/SAM definition.

### What alternatives would need to address

- **Lambda chaining**: would require storing job_id externally (DynamoDB or SSM) between the
  import_launcher invocation and the poller. The 60-second wait would require either SQS
  delay queues, EventBridge Scheduler per-execution rules (complex teardown), or recursive
  async Lambda invocation with `context.invoked_function_arn` and a delay retry.
- **EventBridge Pipes**: suitable for the S3 → transform → HealthLake if HealthLake exposed
  an API target, but the async polling loop is not expressible in Pipes without a SFN target.
- **ECS tasks**: would address the 256 MB Lambda memory constraint on csv_to_fhir_mapper
  (noted as the binding limit for large CSVs), but adds container image management overhead
  that is unnecessary at REDCap export volumes.
- **DTA (HealthLake Data Transformation Agent)**: would eliminate csv_to_fhir_mapper and
  import_launcher entirely (HealthLake handles CSV-to-FHIR conversion natively), but is
  still in Preview (Sep 2026), has a hard 100-column CSV limit, unknown pricing, and a
  1-concurrent-job-per-account limit. The current hand-coded mappings in `mappings/*.py`
  give explicit control over FHIR resource shape that DTA's AI-generated YAML may not match.
