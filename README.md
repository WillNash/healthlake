# REDCap → HealthLake FHIR R4 Pipeline

A proof-of-concept pipeline for ingesting New Zealand clinical registry data from REDCap
into Amazon HealthLake as FHIR R4 resources.

REDCap CSV exports land in an S3 bucket. An EventBridge rule triggers an AWS Step Functions
state machine that maps the CSV rows to FHIR resources via a custom Lambda, writes NDJSON to
a staging bucket, and submits a HealthLake import job. The pipeline polls until the job
completes, and notifies via SNS on failure.

See [`pipeline-flow.md`](pipeline-flow.md) for a detailed step-by-step trace.

---

## Architecture

```
REDCap  ──export──►  S3 landing bucket
                           │
                    EventBridge rule
                           │
                    Step Functions
                     ┌─────┴──────────────────────────┐
                     │                                │
              csv_to_fhir_mapper            import_launcher / import_poller
              (CSV → FHIR NDJSON)           (HealthLake import job)
                     │                                │
              S3 fhir_staging              HealthLake FHIR R4 datastore
```

**Modules**

| Module | Purpose |
|---|---|
| `bootstrap/` | One-time setup: encrypted S3 state bucket + DynamoDB lock table |
| `modules/security` | KMS CMK, CloudTrail |
| `modules/ingestion` | Landing S3 bucket, REDCap exporter Lambda, EventBridge Scheduler |
| `modules/persistence` | HealthLake FHIR R4 datastore, export/import output buckets |
| `modules/transformation` | csv_to_fhir_mapper, import_launcher, import_poller Lambdas, Step Functions |
| `modules/networking` | VPC skeleton (retained for future use; not wired to Lambdas in POC) |

---

## HealthLake regions

HealthLake is only available in eight regions. Choose one and use it consistently for every step below.

| Region | Location |
|---|---|
| `us-east-1` | N. Virginia |
| `us-east-2` | Ohio |
| `us-west-2` | Oregon |
| `ap-south-1` | Mumbai |
| `ap-southeast-2` | Sydney |
| `ca-central-1` | Canada Central |
| `eu-west-1` | Ireland |
| `eu-west-2` | London |

For NZ deployments: `ap-southeast-2` (Sydney) is the closest available region.

---

## Prerequisites

| Tool | Version |
|---|---|
| Terraform | `~> 1.6` |
| AWS CLI | v2 |
| Python | 3.12 (for local mapper testing only) |

AWS credentials must have sufficient permissions to create IAM roles, KMS keys, S3 buckets,
Lambda functions, Step Functions state machines, HealthLake datastores, CloudTrail trails,
EventBridge rules, SNS topics, and SQS queues.

---

## Deploy

### Step 1 — Bootstrap (one-time per account/region)

The bootstrap creates the encrypted S3 bucket and DynamoDB table used to store Terraform
state for all subsequent applies. Run it once. Do not run it again.

```bash
cd bootstrap

# Create a tfvars file for bootstrap
cat > terraform.tfvars <<EOF
aws_region   = "ap-southeast-2"
project_name = "clinical-registry"
environment  = "dev"
EOF

terraform init
terraform apply
```

Note the outputs — you need them in the next step:

```
tfstate_bucket_name      = "clinical-registry-dev-tfstate-123456789012"
dynamodb_lock_table_name = "clinical-registry-dev-tflock"
kms_key_arn              = "arn:aws:kms:ap-southeast-2:123456789012:key/..."
```

### Step 2 — Configure the remote backend

Edit `environments/dev/versions.tf` and fill in the backend block using the bootstrap outputs:

```hcl
backend "s3" {
  bucket         = "clinical-registry-dev-tfstate-123456789012"
  key            = "dev/terraform.tfstate"
  region         = "ap-southeast-2"
  dynamodb_table = "clinical-registry-dev-tflock"
  kms_key_id     = "arn:aws:kms:ap-southeast-2:123456789012:key/..."
  encrypt        = true
}
```

### Step 3 — Create your tfvars file

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set `aws_region` and `project_name`. Set sensitive values via
environment variables rather than writing them into the file:

```bash
export TF_VAR_redcap_url="https://redcap.yourinstitution.ac.nz"
export TF_VAR_redcap_project_id="42"
```

If you are running simulated data only (no live REDCap instance), set placeholder values —
the variables are required by Terraform but the ingestion Lambda is not invoked during simulation:

```bash
export TF_VAR_redcap_url="https://placeholder.example.com"
export TF_VAR_redcap_project_id="0"
```

### Step 4 — Initialise and apply

```bash
cd environments/dev

terraform init
terraform plan
terraform apply
```

> **Note:** The HealthLake FHIR R4 datastore (`awscc_healthlake_fhir_datastore`) takes
> approximately 10–15 minutes to provision. Terraform will wait at this resource until
> HealthLake signals completion. This is normal.

### Step 5 — Note the outputs

```bash
terraform output
```

Key values you will use during simulation and monitoring:

```
landing_bucket_name        = "clinical-registry-dev-landing-abc123"
healthlake_datastore_id    = "abc123..."
healthlake_datastore_endpoint = "https://healthlake.ap-southeast-2.amazonaws.com/datastore/abc123/r4/"
fhir_staging_bucket_name   = "clinical-registry-dev-fhir-staging-xyz456"
import_orchestrator_sfn_arn = "arn:aws:states:ap-southeast-2:123456789012:stateMachine:..."
import_failures_sns_arn    = "arn:aws:sns:ap-southeast-2:123456789012:..."
```

---

## Simulate the pipeline

Use the inject script to upload a sample CSV and trigger the full pipeline without a live
REDCap connection.

```bash
# Get the landing bucket name from Terraform
BUCKET=$(terraform -chdir=environments/dev output -raw landing_bucket_name)

# Inject a sample registry CSV
./simulate/inject.sh heartland_hf "$BUCKET"
./simulate/inject.sh ovarian_cancer "$BUCKET"
./simulate/inject.sh cardiac_surgery "$BUCKET"
```

The script uploads the CSV to `s3://<bucket>/redcap-exports/<registry>/<timestamp>-sim.csv`,
which triggers the EventBridge rule and starts a Step Functions execution within ~30 seconds.

### Monitor the execution

```bash
SFN_ARN=$(terraform -chdir=environments/dev output -raw import_orchestrator_sfn_arn)

# List recent executions
aws stepfunctions list-executions \
  --state-machine-arn "$SFN_ARN" \
  --region ap-southeast-2

# Get detail on the most recent execution
EXEC_ARN=$(aws stepfunctions list-executions \
  --state-machine-arn "$SFN_ARN" \
  --region ap-southeast-2 \
  --query 'executions[0].executionArn' \
  --output text)

aws stepfunctions describe-execution \
  --execution-arn "$EXEC_ARN" \
  --region ap-southeast-2
```

### Query HealthLake after import completes

```bash
ENDPOINT=$(terraform -chdir=environments/dev output -raw healthlake_datastore_endpoint)

# List all patients
aws healthlake get-capabilities \
  --datastore-id $(terraform -chdir=environments/dev output -raw healthlake_datastore_id) \
  --region ap-southeast-2

# FHIR search — all Patient resources
curl -s \
  -H "Authorization: $(aws healthlake describe-fhir-datastore \
    --datastore-id $(terraform -chdir=environments/dev output -raw healthlake_datastore_id) \
    --region ap-southeast-2 --query 'DatastoreProperties.DatastoreEndpoint' --output text)/Patient" \
  "$ENDPOINT/Patient" | python3 -m json.tool
```

---

## Running the pipeline with live REDCap data

When REDCap project IDs are known, update the `registry_map` variable in `terraform.tfvars`:

```hcl
registry_map = {
  "1001" = "ovarian_cancer"
  "1002" = "cardiac_surgery"
}
```

Re-apply:

```bash
terraform apply
```

The ingestion module's EventBridge Scheduler triggers the `redcap_exporter` Lambda nightly
at 02:00 UTC (configurable via `export_schedule_expression`). The Lambda calls the REDCap
API, writes the CSV to the landing bucket, and the pipeline runs automatically.

Store the REDCap API token after first apply:

```bash
aws secretsmanager put-secret-value \
  --secret-id "/clinical-registry/dev/redcap-api-token" \
  --secret-string '{"token": "your-redcap-api-token-here"}' \
  --region ap-southeast-2
```

---

## Adding a new registry

1. Create a mapping module at `modules/transformation/lambda/csv_to_fhir_mapper/mappings/<name>.py`
   implementing `def map_row(row: dict) -> list`. See `mappings/heartland_hf.py` for an example
   that handles REDCap repeating instruments.

2. Add the registry name to `_KNOWN` in `handler.py` and add an import case to `_get_mapping_fn`.

3. Add a sample CSV to `simulate/registries/<name>/export.csv` and a `mapping_spec.md`
   documenting the field-to-FHIR mappings and any codes pending clinical review.

4. Test locally:
   ```bash
   cd modules/transformation/lambda/csv_to_fhir_mapper
   python3 -c "
   import csv, json
   from mappings.<name> import map_row
   with open('../../../simulate/registries/<name>/export.csv') as f:
       for row in csv.DictReader(f):
           for r in map_row(row):
               print(json.dumps(r))
   "
   ```

5. Deploy and simulate:
   ```bash
   terraform -chdir=environments/dev apply
   ./simulate/inject.sh <name> $(terraform -chdir=environments/dev output -raw landing_bucket_name)
   ```

---

## Tearing down

Several resources have `prevent_destroy = true` to guard against accidental data loss:
- HealthLake FHIR R4 datastore
- KMS keys (both the clinical CMK and the HealthLake-specific key)
- Landing, fhir_export, and import_output S3 buckets
- CloudTrail S3 bucket

To tear down the environment you must first remove these lifecycle constraints from the
Terraform source, then run `terraform destroy`. The KMS keys will enter a 30-day deletion
pending period regardless.

The bootstrap state bucket and DynamoDB lock table also have `prevent_destroy = true`
and must be deleted manually via the AWS console or CLI after all environment state has
been removed.

---

## Cost estimate (dev, ap-southeast-2)

| Service | Monthly cost |
|---|---|
| KMS CMKs (×2) | $2.00 |
| Secrets Manager (×1 secret) | $0.40 |
| HealthLake (POC data volume) | ~$0 |
| Lambda, Step Functions, S3, SNS, SQS | ~$0 |
| CloudTrail (management events, single-region) | $0 |
| **Total** | **~$2.50/month** |

Lambda functions run outside a VPC. If VPC isolation is required before handling real
patient data, the `modules/networking` module is available to re-enable VPC endpoints —
see the module's `main.tf` for the full interface endpoint configuration.

---

## Repository layout

```
bootstrap/                  One-time state backend setup
environments/
  dev/                      Dev environment root module
  prod/                     Prod environment root module
modules/
  security/                 KMS CMK, CloudTrail
  ingestion/                Landing bucket, redcap_exporter Lambda, scheduler
  persistence/              HealthLake datastore, export/import output buckets
  transformation/           Step Functions, csv_to_fhir_mapper, import_launcher, import_poller
    lambda/
      csv_to_fhir_mapper/
        handler.py          Registry detection, CSV → NDJSON orchestration
        fhir_builder.py     FHIR R4 resource constructors
        mappings/
          ovarian_cancer.py
          cardiac_surgery.py
          heartland_hf.py   HEARTLAND HF registry (repeating instruments demo)
      import_launcher/      Starts HealthLake FHIR import job
      import_poller/        Polls import job status
  networking/               VPC skeleton (not wired in POC; available for production)
simulate/
  inject.sh                 Upload a sample CSV to trigger the pipeline
  registries/
    ovarian_cancer/         Sample CSV + mapping spec
    cardiac_surgery/        Sample CSV + mapping spec
    heartland_hf/           Real HEARTLAND HF dataset + data dictionary + mapping spec
pipeline-flow.md            End-to-end pipeline trace with code references
dta-findings.md             Research on AWS HealthLake Data Transformation Agent (Preview)
```

---

## Key documents

| Document | Contents |
|---|---|
| [`pipeline-flow.md`](pipeline-flow.md) | Step-by-step trace of a CSV through the pipeline |
| [`sm-input-size-constraints.md`](sm-input-size-constraints.md) | Input size limits at each pipeline layer and how to raise them |
| [`dta-findings.md`](dta-findings.md) | Research on the HealthLake DTA — current Preview status, CSV support, quotas |
| [`simulate/registries/heartland_hf/mapping_spec.md`](simulate/registries/heartland_hf/mapping_spec.md) | HEARTLAND HF field → FHIR mapping reference |
| [`simulate/registries/ovarian_cancer/mapping_spec.md`](simulate/registries/ovarian_cancer/mapping_spec.md) | Ovarian cancer registry mapping spec |
| [`simulate/registries/cardiac_surgery/mapping_spec.md`](simulate/registries/cardiac_surgery/mapping_spec.md) | Cardiac surgery registry mapping spec |
