# Pipeline Flow: REDCap CSV → HealthLake FHIR R4

End-to-end trace of what happens when a REDCap CSV export lands in the pipeline.

---

## Data flow overview

```
EventBridge Scheduler (nightly cron)
  └─ redcap_exporter Lambda
       └─ REDCap API → CSV → S3 landing bucket
            └─ Object Created event → EventBridge
                 └─ EventBridge rule → Step Functions execution
                      ├─ csv_to_fhir_mapper Lambda
                      │    ├─ reads CSV from landing bucket
                      │    ├─ detects registry from S3 key
                      │    ├─ runs mapping module (row-by-row → FHIR dicts)
                      │    └─ writes NDJSON to fhir_staging bucket
                      ├─ import_launcher Lambda
                      │    └─ calls HealthLake start_fhir_import_job
                      ├─ [60s wait loop via import_poller]
                      └─ HealthLake datastore (FHIR R4 resources queryable)
```

---

## Step 0 — REDCap exporter runs on schedule

EventBridge Scheduler fires the `redcap_exporter` Lambda on the configured cron
(`export_schedule_expression` — default `cron(0 2 * * ? *)`, 2 AM UTC daily).

### Inside the Lambda (`modules/ingestion/lambda/redcap_exporter/handler.py`)

1. Retrieves the REDCap API token from Secrets Manager
   (`/<project_name>/<env>/redcap-api-token/<registry_name>`).

2. POSTs to the REDCap API (`/api/index.php`) with `content=record&format=csv&type=flat`.

3. Writes the CSV response to the landing bucket at:
   ```
   redcap-exports/<YYYY>/<MM>/<DD>/<HHMMSS>-<project_id>.csv
   ```

4. Returns `{"bucket": "<name>", "key": "<key>"}` — not consumed downstream; the
   EventBridge S3 notification triggers the next stage independently.

The Lambda has `maximum_retry_attempts = 0` (no async retry). Failures land on the
`redcap-exporter-dlq` SQS queue (`modules/ingestion/main.tf`).

> **First-time setup:** The placeholder token `{"token": "REPLACE_ME"}` is written to
> Secrets Manager on first apply. Update it manually before the first scheduled run:
> ```
> aws secretsmanager put-secret-value \
>   --secret-id /<project_name>/<env>/redcap-api-token \
>   --secret-string '{"token":"<your-redcap-api-token>"}'
> ```

---

## Step 1 — CSV lands in the S3 landing bucket

A file is written to S3 at a key matching:

```
redcap-exports/<registry>/<filename>.csv
```

Examples:
- Simulation: `redcap-exports/heartland_hf/2026-09-28T120000-sim.csv`
- Production: `redcap-exports/2026/09/28/120000-1001.csv` (where `1001` is the REDCap project ID)

The landing bucket has `eventbridge = true` on its S3 notification configuration
(`modules/ingestion/main.tf`), so S3 publishes an `Object Created` event to the
account-default EventBridge bus automatically — no polling required.

---

## Step 2 — EventBridge rule fires

The rule (`modules/transformation/main.tf`) matches:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": { "name": ["<landing-bucket-name>"] },
    "object": { "key": [{ "prefix": "redcap-exports/" }] }
  }
}
```

The target is the Step Functions state machine, invoked via the `events_to_sfn` IAM role.
The **entire EventBridge event becomes the Step Functions execution input** — so `$` inside
the state machine is the raw S3 event object.

---

## Step 3 — Step Functions: MapCSVToFHIR

Invokes the `csv_to_fhir_mapper` Lambda with `Payload.$: "$"` (the full S3 event).

### Inside the Lambda (`modules/transformation/lambda/csv_to_fhir_mapper/handler.py`)

1. Extracts `detail.bucket.name` and `detail.object.key` from the event.

2. Runs `_detect_registry(key)`:
   - **Simulation paths** — matches `key.split("/")[1]` against the `_KNOWN` frozenset
     (`ovarian_cancer`, `cardiac_surgery`, `heartland_hf`). No environment config needed.
   - **Production paths** — matches the filename suffix `*-<project_id>.csv` against the
     `REGISTRY_MAP` environment variable (a JSON map of REDCap project IDs to registry names).

3. Downloads the CSV from S3 via `s3.get_object`, stripping a UTF-8 BOM if present.

4. Loads the registry-specific `map_row` function from `mappings/<registry>.py`.

5. Iterates every CSV row through `map_row`, which returns a list of FHIR resource dicts.
   Registries using REDCap repeating instruments (e.g. `heartland_hf`) return resources
   only from the relevant row type — baseline rows produce Patient/Condition/Observation,
   monthly follow-up rows produce per-visit Observations.

6. Serialises all resources to NDJSON (one compact JSON object per line).

7. Writes the NDJSON to the staging bucket:
   ```
   s3://fhir-staging-bucket/fhir-ndjson/<registry>/<YYYY>/<MM>/<DD>/<HHMMSS>.ndjson
   ```

### Payload returned to Step Functions as `$.mapper_result.Payload`

```json
{
  "fhir_bucket": "clinical-registry-dev-fhir-staging-abc123",
  "fhir_key": "fhir-ndjson/heartland_hf/2026/09/28/120001.ndjson",
  "resource_count": 340,
  "skipped_rows": 0,
  "registry": "heartland_hf",
  "source_key": "redcap-exports/heartland_hf/2026-09-28T120000-sim.csv"
}
```

If this Lambda throws for any reason, the `Catch` block routes execution to `NotifyFailure`.

---

## Step 4 — Step Functions: LaunchImportJob

Invokes the `import_launcher` Lambda with `Payload.$: "$.mapper_result.Payload"`.

### Inside the Lambda (`modules/transformation/lambda/import_launcher/handler.py`)

1. Reads `fhir_bucket` and `fhir_key` from the event.

2. Derives a `ClientToken` by MD5-hashing `fhir_key`. This makes retries idempotent —
   HealthLake deduplicates import jobs on `ClientToken`, so a SFN retry after a transient
   failure will not create a duplicate job.

3. Calls `healthlake.start_fhir_import_job`:
   - `InputDataConfig.S3Uri` → the NDJSON file written in step 3
   - `JobOutputDataConfig` → `s3://import-output-bucket/import-output/` with KMS key
   - `DataAccessRoleArn` → the HealthLake data access role (has `s3:GetObject` on the
     staging bucket and `s3:PutObject` on the import output bucket)
   - `JobName` → `import-<registry>-<first-8-chars-of-token>`

4. HealthLake acknowledges synchronously and returns a `JobId`. The actual FHIR ingestion
   happens asynchronously — the job is queued.

### Payload returned to Step Functions as `$.import_result.Payload`

```json
{
  "job_id": "abc123def456...",
  "fhir_key": "fhir-ndjson/heartland_hf/2026/09/28/120001.ndjson",
  "registry": "heartland_hf"
}
```

---

## Step 5 — Step Functions: WaitForImport

A `Wait` state — pauses execution for **60 seconds**. No Lambda invocation, no cost
beyond the SFN wait. HealthLake import jobs are asynchronous; small files typically
complete in 1–5 minutes.

---

## Step 6 — Step Functions: PollImportStatus

Invokes the `import_poller` Lambda with `Payload.$: "$.import_result.Payload"`.

### Inside the Lambda (`modules/transformation/lambda/import_poller/handler.py`)

1. Calls `healthlake.describe_fhir_import_job` with the `JobId`.
2. Returns the `JobStatus` field from the response.

### Payload returned to Step Functions as `$.poll_result.Payload`

```json
{
  "job_id": "abc123def456...",
  "status": "COMPLETED",
  "registry": "heartland_hf"
}
```

Possible status values: `SUBMITTED`, `IN_PROGRESS`, `COMPLETED`, `FAILED`.

---

## Step 7 — Step Functions: CheckImportStatus

A `Choice` state — no Lambda invocation, pure Step Functions logic:

| `$.poll_result.Payload.status` | Next state |
|---|---|
| `COMPLETED` | `ImportComplete` |
| `FAILED` | `NotifyFailure` |
| `SUBMITTED` or `IN_PROGRESS` | `WaitForImport` (loops back to step 5) |

The 60-second wait-and-poll loop repeats until the job reaches a terminal status.

---

## Step 8a — ImportComplete

A `Succeed` terminal state. Execution ends normally.

The FHIR resources are now in the HealthLake datastore and queryable via the FHIR
REST API endpoint (`modules/persistence/outputs.tf: datastore_endpoint`).

The NDJSON file remains in the staging bucket until the 14-day lifecycle rule
expires it (prefix `fhir-ndjson/`, `modules/transformation/main.tf`).

---

## Step 8b — NotifyFailure → ImportFailed

Triggered when any step throws an unhandled error, or when HealthLake reports
`JobStatus: FAILED`.

1. A `Task` state calls `sns:Publish` on the `import-failures` SNS topic, with the
   full Step Functions context serialised as the message body via `States.JsonToString($)`.
2. Execution moves to `ImportFailed`, a `Fail` terminal state.

Any subscriber on the SNS topic (email, PagerDuty, Lambda, etc.) receives the failure
detail including which registry, which source file, and which step failed.

---

## Registry detection reference

| S3 key pattern | Detection method | Registry |
|---|---|---|
| `redcap-exports/heartland_hf/...` | Path segment, `_KNOWN` frozenset | `heartland_hf` |
| `redcap-exports/ovarian_cancer/...` | Path segment, `_KNOWN` frozenset | `ovarian_cancer` |
| `redcap-exports/cardiac_surgery/...` | Path segment, `_KNOWN` frozenset | `cardiac_surgery` |
| `redcap-exports/.../...-1001.csv` | Filename suffix, `REGISTRY_MAP` env var | configurable |

To add a new registry: implement `mappings/<name>.py`, add the name to `_KNOWN` in
`handler.py`, and add the import in `_get_mapping_fn`.

---

## Relevant source files

| File | Role |
|---|---|
| `modules/ingestion/main.tf` | Landing bucket, EventBridge notification, Scheduler, redcap_exporter Lambda |
| `modules/ingestion/lambda/redcap_exporter/handler.py` | REDCap API export → S3 |
| `modules/transformation/main.tf` | EventBridge rule, SFN state machine definition, all transformation Lambdas |
| `modules/transformation/iam.tf` | IAM roles and policies for all Lambdas and SFN |
| `modules/transformation/lambda/csv_to_fhir_mapper/handler.py` | Registry detection, CSV → NDJSON |
| `modules/transformation/lambda/csv_to_fhir_mapper/fhir_builder.py` | FHIR resource constructors |
| `modules/transformation/lambda/csv_to_fhir_mapper/mappings/` | Per-registry field mappings |
| `modules/transformation/lambda/import_launcher/handler.py` | HealthLake import job submission |
| `modules/transformation/lambda/import_poller/handler.py` | Import job status polling |
| `modules/persistence/main.tf` | HealthLake datastore, import output bucket |
| `simulate/inject.sh` | Upload a simulate CSV to trigger the pipeline manually |

---

## Deploying

### 1 — Bootstrap (once per account/environment)

Creates the Terraform state S3 bucket, DynamoDB lock table, and KMS key.

```bash
cd bootstrap
terraform init
terraform apply -var="project_name=clinical-registry" -var="environment=dev"
```

Copy the outputs into `environments/dev/backend.hcl` (created from the example):

```bash
cp environments/dev/backend.hcl.example environments/dev/backend.hcl
# edit backend.hcl with the bootstrap output values
```

### 2 — Environment apply

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init -backend-config=backend.hcl
terraform apply
```

Sensitive variables (`redcap_url`, `redcap_project_id`) should be passed via
environment variables rather than committed to `terraform.tfvars`:

```bash
export TF_VAR_redcap_url="https://redcap.example.com"
export TF_VAR_redcap_project_id="42"
terraform apply
```

### 3 — Post-deploy: set REDCap API tokens

For each project in `redcap_projects`, the apply writes a placeholder token to Secrets
Manager. Replace each one before the first scheduled run:

```bash
aws secretsmanager put-secret-value \
  --secret-id /clinical-registry/dev/redcap-api-token/ovarian_cancer \
  --secret-string '{"token":"<ovarian-cancer-api-token>"}'

aws secretsmanager put-secret-value \
  --secret-id /clinical-registry/dev/redcap-api-token/cardiac_surgery \
  --secret-string '{"token":"<cardiac-surgery-api-token>"}'
```

Skipped entirely in simulate mode — no projects means no secrets are created.

### 4 — Post-deploy: configure the registry map

Add REDCap project IDs → registry names in `terraform.tfvars` and re-apply so the
transformation Lambda can route production exports to the right mapping module:

```hcl
registry_map = {
  "42" = "ovarian_cancer"
  "17" = "cardiac_surgery"
}
```

The key must match the `project_id` value in `redcap_projects`.

### 5 — Verify with a simulate run

```bash
BUCKET=$(terraform -chdir=environments/dev output -raw landing_bucket_name)
./simulate/inject.sh heartland_hf $BUCKET

# Watch the Step Functions execution
aws stepfunctions list-executions \
  --state-machine-arn $(terraform -chdir=environments/dev output -raw import_orchestrator_sfn_arn) \
  --query 'executions[0]'
```
