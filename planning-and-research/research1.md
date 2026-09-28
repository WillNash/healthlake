# Research Findings: Clinical Registry Data Pipeline on AWS with Terraform

## Source URLs

- [AWS HealthLake Developer Guide — What is AWS HealthLake](https://docs.aws.amazon.com/healthlake/latest/devguide/what-is.html) — **Official**
- [AWS HealthLake — Transforming healthcare data (Data Transformation Agent)](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation.html) — **Official**
- [AWS HealthLake — Data Transformation Features](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-features.html) — **Official**
- [AWS HealthLake — Getting started with the SDK and AWS CLI](https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-getting-started-cli.html) — **Official**
- [AWS HealthLake — StartFHIRImportJob CLI reference](https://docs.aws.amazon.com/cli/latest/reference/healthlake/start-fhir-import-job.html) — **Official**
- [AWS HealthLake — Integrated NLP](https://docs.aws.amazon.com/healthlake/latest/devguide/integrated-medical-nlp.html) — **Official**
- [AWS HealthLake — VPC endpoints (PrivateLink)](https://docs.aws.amazon.com/healthlake/latest/devguide/vpc-endpoints.html) — **Official**
- [AWS CloudFormation — AWS::HealthLake::FHIRDatastore](https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-healthlake-fhirdatastore.html) — **Official**
- [Amazon Athena — Query Apache Iceberg tables](https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html) — **Official**
- [Amazon Comprehend Medical — Prescriptive Guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/generative-ai-nlp-healthcare/comprehend-medical.html) — **Official**
- [Amazon HealthLake — Asia Pacific (Mumbai) region announcement](https://aws.amazon.com/about-aws/whats-new/2023/04/amazon-healthlake-asia-pacific-mumbai-region) — **Official**
- [AWS HealthLake Data Transformation Agent Preview announcement (March 2026)](https://aws.amazon.com/about-aws/whats-new/2026/03/aws-healthlake-data-transformation-agent) — **Official**
- [Terraform Registry — awscc_healthlake_fhir_datastore](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/healthlake_fhir_datastore) — **Official**
- [Terraform Registry — aws_glue_catalog_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/glue_catalog_table) — **Official**
- [Terraform Registry — aws_quicksight_data_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/quicksight_data_source) — **Official**
- [Terraform Registry — aws_lakeformation_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) — **Official**
- [Terraform Registry — aws_lakeformation_resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_resource) — **Official**
- [Terraform Registry — aws_comprehend_entity_recognizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/comprehend_entity_recognizer) — **Official**
- [REDCap Knowledge Base — REDCap API](https://bdeveer.github.io/REDCap_KB_RAG/RC-API-01_REDCap-API/) — Semi-official (community knowledge base)
- [MITRE FHIR for Research — REDCap on FHIR](https://mitre.github.io/fhir-for-research/modules/redcap-fhir) — Semi-official (MITRE engineering blog/guide)
- [GitHub — AWS Samples: redcap-on-aws](https://github.com/aws-samples/redcap-on-aws) — Semi-official (AWS Samples GitHub)
- [GitHub — aehrc/redmatch](https://github.com/aehrc/redmatch) — Semi-official (CSIRO AEHRC GitHub)
- [GitHub Issue — awscc_healthlake_fhir_datastore forced replacement (#1298)](https://github.com/hashicorp/terraform-provider-awscc/issues/1298) — Semi-official (GitHub issue thread)
- [GitHub Issue — aws_glue_catalog_table open_table_format_input Iceberg (#33157)](https://github.com/hashicorp/terraform-provider-aws/issues/33157) — Semi-official (GitHub issue thread)
- [Implementing SMART-on-FHIR with AWS HealthLake Using Terraform — themomentum.ai](https://www.themomentum.ai/blog/how-to-implement-smart-on-fhir-with-aws-healthlake-using-terraform) — ⚠️ Unofficial (vendor blog)
- [HIPAA on AWS: Engineer's Build Guide (KMS, VPC, RDS, S3) — factualminds.com](https://www.factualminds.com/blog/how-to-implement-hipaa-compliant-architecture-aws/) — ⚠️ Unofficial (community blog)
- [Serverless Land — SFN + Comprehend Terraform pattern](https://serverlessland.com/patterns/sfn-comprehend-terraform) — Semi-official (AWS Serverless Land, AWS-curated)

---

## Core Concepts

### 1. AWS HealthLake Terraform Resources

**Provider**: HealthLake is managed via the `awscc` (AWS Cloud Control) Terraform provider, NOT the standard `hashicorp/aws` provider. The resource name is `awscc_healthlake_fhir_datastore`. The `awscc` provider auto-generates resources from CloudFormation schemas.

**FHIR version**: Only R4 is supported. There is no R5 support.

**Regions (as of mid-2026)**:
- US East (N. Virginia) — `us-east-1`
- US East (Ohio) — `us-east-2`
- US West (Oregon) — `us-west-2`
- Asia Pacific (Mumbai) — `ap-south-1`

**Datastore lifecycle**: All properties (`DatastoreName`, `DatastoreTypeVersion`, `PreloadDataConfig`, `SseConfiguration`, `IdentityProviderConfiguration`) require **Replacement** on update — meaning changing any of these destroys and recreates the datastore, with potential data loss. Only `Tags` can be updated in place.

**Computed outputs** (available as Terraform attributes after creation):
- `datastore_arn`
- `datastore_endpoint`
- `datastore_id`
- `datastore_status` (values: `CREATING`, `ACTIVE`, `DELETING`, `DELETED`)

**Encryption options** (via `sse_configuration.kms_encryption_config.cmk_type`):
- `AWS_OWNED_KMS_KEY` — AWS-managed key, no additional setup
- `CUSTOMER_MANAGED_KMS_KEY` — requires a customer-managed KMS key ARN via `kms_key_id`

**Integrated NLP**: HealthLake's integrated NLP (backed by Comprehend Medical) is **disabled by default** and must be enabled by submitting an AWS Support case. It is not a Terraform-configurable toggle.

**VPC isolation**: HealthLake supports interface VPC endpoints via AWS PrivateLink. Service name: `com.amazonaws.<region>.healthlake`. All API actions are available through the VPC endpoint.

---

### 2. HealthLake Data Transformation Agent

**Status**: In Preview (announced March 2026). APIs and behavior may change before GA. Pricing will be announced at GA; preview usage should be confirmed with AWS account team for production readiness.

**Supported input formats**: C-CDA (XML clinical documents) and CSV (relational/tabular data). REDCap CSV exports are a direct fit for the CSV profile path.

**How it works**:
1. You create a **Transformation Profile** — a versioned, reusable definition of how source data maps to FHIR R4.
   - For C-CDA: profile contains Velocity templates.
   - For CSV: profile contains a YAML mapping configuration.
2. An **AI Agent** (LLM-powered) can author and edit the profile from natural language instructions.
3. You publish an immutable version of the profile.
4. You run a **Transformation Job** (bulk, async) against S3 input, using the published profile.

**Two bulk job modes**:
- **Standalone** (`start-data-transformation-job`): writes FHIR NDJSON to an S3 output location.
- **Composite / Convert-and-Ingest** (`start-fhir-import-job` with `--profile-id` and `--input-format`): converts source files AND ingests directly into a HealthLake datastore in one step.

**Key point for the pipeline**: The `StartFHIRImportJob` API with `--profile-id` and `--input-format CCDA` or `CSV` is the single API call that covers both transformation and persistence. This replaces any need for custom Lambda-based transformation logic.

**Sync (real-time) conversion endpoint**: `POST https://datatransformation.healthlake.<region>.amazonaws.com/transform-data` — REST-only, not exposed as a CLI/SDK command. Size limit: 1 MB per request.

**Provenance**: Enabled by default. Generates a US Core-conformant FHIR Provenance resource for every conversion, tracing each output resource to its S3 source file (with SHA-1 checksum) and exact record location (XPath for C-CDA, table/row for CSV).

**Drift detection**: Optional flag on both sync and bulk jobs. Reports unmapped source sections/columns, coverage rates, and missing expected resources.

**No native Terraform resource for import jobs**: The `start-fhir-import-job` and `start-data-transformation-job` are API operations (run-once jobs), not persistent infrastructure. They are orchestrated via Lambda + Step Functions or EventBridge Pipes, not Terraform resources.

---

### 3. HealthLake Integrated NLP (Comprehend Medical)

**What it does**: When enabled, HealthLake automatically calls Amazon Comprehend Medical on text stored in `DocumentReference` FHIR resources. Specifically it calls:
- `DetectEntities-V2`
- `InferICD10-CM`
- `InferRxNorm`

Results are appended as extensions on the `DocumentReference`. When entities with traits `SIGN`, `SYMPTOM`, or `DIAGNOSIS` are detected, new `Condition` and `Observation` FHIR resources are generated and linked to the source document via a `Linkage` resource.

**Important**: The generated NLP-derived resources can be queried via Athena (SQL) but NOT via FHIR API search parameters.

**Terraform consideration**: There is no Terraform resource to enable or configure integrated NLP. Enablement requires an AWS Support ticket. IAM permissions for the HealthLake service role must include `comprehendmedical:*` actions.

---

### 4. Comprehend Medical as a Standalone Pipeline Component

If integrated NLP is not enabled (or for custom pipelines), Comprehend Medical is invoked as a Lambda function using the boto3 `comprehendmedical` client. There are **no `aws_comprehend_medical_*` Terraform resources** in the `hashicorp/aws` provider. The Terraform provider only has `aws_comprehend_document_classifier` and `aws_comprehend_entity_recognizer` (for custom models), which are irrelevant to the medical entity detection APIs.

**Pattern**: Lambda function → `boto3.client('comprehendmedical').detect_entities_v2(Text=...)` → writes structured output to S3 or calls HealthLake FHIR API to create `DocumentReference` or `Observation` resources.

**Terraform manages**: the Lambda function resource, IAM role with `comprehendmedical:DetectEntitiesV2`, `comprehendmedical:InferICD10CM`, `comprehendmedical:InferRxNorm` permissions, and the S3 trigger or Step Functions state machine that invokes it.

---

### 5. REDCap API Export

**Endpoint**: Single HTTP POST to `https://<redcap-host>/api/index.php`

**Export formats**: JSON (default, recommended), CSV (spreadsheet-compatible), XML (including CDISC ODM flavor). All via the `Export Records` method.

**Authentication**: 32-character project-scoped API token, passed as a POST parameter. Requires HTTPS. Export rights are scoped to the user's project permissions.

**Pagination**: For large projects, use `records` or `events` parameters to paginate. No documented rate limits.

**REDCap to FHIR mapping options**:
- **REDCap on FHIR (CDIS module)**: Built into REDCap, pulls from EHR FHIR APIs into REDCap. Works for prospective data collection. Does NOT export REDCap data as FHIR.
- **Redmatch** (CSIRO AEHRC): Open-source DSL-based tool for defining REDCap-to-FHIR transformation rules. Experimental status, not production-hardened. Outputs FHIR JSON-LD.
- **HealthLake Data Transformation Agent (CSV profile)**: Best fit for this pipeline. REDCap CSV export → S3 → DTA CSV profile → FHIR R4 → HealthLake.
- **Custom Lambda**: REDCap API → Lambda (Python/requests) → writes FHIR JSON to S3 or directly to HealthLake via FHIR REST API.

**Recommended pattern for this pipeline**:
1. EventBridge Scheduler (cron) triggers a Lambda function.
2. Lambda calls REDCap API (`action=exportRecords&format=csv`) and streams the response to an S3 bucket (`s3://ingestion-bucket/redcap-exports/<timestamp>/`).
3. S3 event notification (or EventBridge rule on `s3:ObjectCreated`) triggers the DTA import job via Lambda calling `start-fhir-import-job` with `--profile-id` (CSV profile) and `--input-format CSV`.

---

### 6. Athena + Iceberg Tables in Terraform

**Athena Iceberg version**: Athena Engine v3 supports Apache Iceberg 1.4.2 and creates v2 tables (row-level deletes, merge-on-read).

**Supported file formats**: Parquet (recommended for analytics), ORC, Avro.

**Terraform resource for Iceberg tables**: `aws_glue_catalog_table` with the `open_table_format_input` block.

```hcl
resource "aws_glue_catalog_table" "fhir_patient" {
  name          = "patient"
  database_name = aws_glue_catalog_database.fhir.name

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"  # only valid value
      version            = 2
    }
  }

  storage_descriptor {
    location      = "s3://analytics-bucket/fhir/patient/"
    input_format  = "org.apache.hadoop.mapred.FileInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "id"
      type = "string"
    }
    columns {
      name = "birthdate"
      type = "date"
    }
  }
}
```

**Key limitations**:
- Athena does not support DDL operations (CREATE, ALTER, DROP) on Iceberg tables registered with Lake Formation.
- `ALTER TABLE SET LOCATION` is not supported for Iceberg tables.
- Athena uses AWS Glue optimistic locking only — using any other lock implementation with Athena will cause data loss.
- Partitioning by nested fields is not supported.
- Timestamp precision is milliseconds in Athena (Iceberg supports microseconds, but Athena truncates).
- `open_table_format_input` **cannot be added to an existing** `aws_glue_catalog_table` — it will force destroy+recreate. Plan accordingly.

**Known Terraform bug**: Adding `open_table_format_input` to an existing Glue table causes the resource to be destroyed and recreated. Importing existing Iceberg-based Glue tables also causes deletion. Track GitHub issue #46999 and #33370 for status.

**Athena workgroup (required for query cost control and encryption)**:

```hcl
resource "aws_athena_workgroup" "fhir_analytics" {
  name = "fhir-analytics"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.main.arn
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }
}

resource "aws_athena_database" "fhir" {
  name   = "fhir_registry"
  bucket = aws_s3_bucket.athena_results.bucket
}
```

---

### 7. QuickSight Terraform Resources

**Resource**: `aws_quicksight_data_source` with `type = "ATHENA"`.

```hcl
resource "aws_quicksight_data_source" "fhir_athena" {
  data_source_id = "fhir-athena-source"
  name           = "FHIR Registry Athena"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = aws_athena_workgroup.fhir_analytics.name
    }
  }

  permission {
    actions = [
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:DeleteDataSource",
      "quicksight:UpdateDataSourcePermissions",
    ]
    principal = "arn:aws:quicksight:${var.region}:${data.aws_caller_identity.current.account_id}:user/default/${var.quicksight_admin_user}"
  }

  ssl_properties {
    disable_ssl = false
  }
}
```

**QuickSight limitations in Terraform**: QuickSight requires the QuickSight account to already be subscribed (first-time setup via Console or API, not Terraform). Dashboards and analyses are difficult to manage fully in Terraform — most teams manage datasets and data sources in Terraform but author dashboards in the QuickSight console. The `aws_quicksight_data_set` resource exists but is complex. A dataset referencing an Athena data source requires specifying physical and logical table maps in HCL.

---

### 8. SageMaker Domain Terraform Resource

**Resource**: `aws_sagemaker_domain`

```hcl
resource "aws_sagemaker_domain" "ml_domain" {
  domain_name             = "clinical-registry-ml"
  auth_mode               = "IAM"
  vpc_id                  = aws_vpc.main.id
  subnet_ids              = aws_subnet.private[*].id
  app_network_access_type = "VpcOnly"  # HIPAA: keep in VPC
  kms_key_id              = aws_kms_key.main.arn

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution.arn

    security_groups = [aws_security_group.sagemaker.id]

    sharing_settings {
      notebook_output_option = "Disabled"  # prevents data exfiltration
      s3_kms_key_id          = aws_kms_key.main.arn
      s3_output_path         = "s3://${aws_s3_bucket.sagemaker.bucket}/outputs/"
    }
  }

  app_security_group_management = "Customer"
}
```

**Key parameters**:
- `app_network_access_type`: `PublicInternetOnly` (default) or `VpcOnly` (required for HIPAA)
- `app_security_group_management`: `Service` or `Customer` — required in `VpcOnly` mode
- `kms_key_id`: encrypts the EFS volume attached to Studio
- At least 2 private subnets in different AZs required for high availability

---

### 9. Lake Formation (Data Governance)

**Resources**:
- `aws_lakeformation_resource`: registers an S3 location under Lake Formation governance
- `aws_lakeformation_permissions`: grants table/database/column-level permissions to principals

```hcl
resource "aws_lakeformation_resource" "fhir_bucket" {
  arn      = aws_s3_bucket.fhir_data.arn
  role_arn = aws_iam_role.lakeformation_service.arn
}

resource "aws_lakeformation_permissions" "sagemaker_read" {
  principal   = aws_iam_role.sagemaker_execution.arn

  table {
    database_name = aws_glue_catalog_database.fhir.name
    name          = aws_glue_catalog_table.fhir_patient.name
  }

  permissions = ["SELECT", "DESCRIBE"]
}
```

**Athena + Lake Formation conflict**: Athena does NOT support DDL operations on Iceberg tables registered with Lake Formation. If Lake Formation row/cell filters are active on a table, Iceberg metadata tables (`$partitions`, `$files`, `$manifests`, `$snapshots`) return `AccessDeniedException`. Lake Formation cannot manage `VACUUM`, `MERGE`, `UPDATE`, or `OPTIMIZE` operations on Iceberg tables.

**Recommendation**: For HealthLake analytics integration, use Lake Formation for governing S3 paths and Glue catalog databases/tables. Keep Iceberg compaction/vacuum operations running under a dedicated IAM role that bypasses Lake Formation (uses IAM-based Glue access instead).

---

### 10. HIPAA / Compliance Terraform Patterns

**Mandatory controls**:

**KMS key (use one per environment, enable rotation)**:
```hcl
resource "aws_kms_key" "main" {
  description             = "Clinical registry encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "Allow HealthLake"
        Effect = "Allow"
        Principal = { Service = "healthlake.amazonaws.com" }
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}
```

**S3 bucket — deny unencrypted puts, deny HTTP**:
```hcl
resource "aws_s3_bucket_policy" "enforce_encryption" {
  bucket = aws_s3_bucket.clinical_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.clinical_data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption"            = "aws:kms"
            "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.main.arn
          }
        }
      },
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.clinical_data.arn,
          "${aws_s3_bucket.clinical_data.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}
```

**CloudTrail (multi-region, log file validation)**:
```hcl
resource "aws_cloudtrail" "clinical_trail" {
  name                          = "clinical-registry-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.main.arn
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]
}
```

**HealthLake VPC endpoint**:
```hcl
resource "aws_vpc_endpoint" "healthlake" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.healthlake"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoints.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
}
```

**BAA requirement**: AWS HealthLake is HIPAA-eligible. A Business Associate Agreement must be signed with AWS (via AWS Artifact) before processing PHI. Terraform cannot provision or automate the BAA.

---

## Code Snippets

### awscc_healthlake_fhir_datastore (full example with CMK)

```hcl
terraform {
  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_kms_key" "healthlake" {
  description             = "HealthLake FHIR datastore encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid    = "HealthLakeAccess"
        Effect = "Allow"
        Principal = { Service = "healthlake.amazonaws.com" }
        Action   = ["kms:GenerateDataKey", "kms:Decrypt", "kms:DescribeKey"]
        Resource = "*"
      }
    ]
  })
}

resource "awscc_healthlake_fhir_datastore" "main" {
  datastore_name         = var.datastore_name
  datastore_type_version = "R4"

  sse_configuration {
    kms_encryption_config {
      cmk_type   = "CUSTOMER_MANAGED_KMS_KEY"
      kms_key_id = aws_kms_key.healthlake.arn
    }
  }

  # Do NOT set preload_data_config for production — use only for dev/test
  # Setting it causes forced replacement on every plan (see Gotchas)

  tags = [
    { key = "Environment", value = var.environment },
    { key = "HIPAA",        value = "true" }
  ]

  lifecycle {
    # Workaround for awscc provider bug: preload_data_config causes
    # forced replacement even without config changes. See GitHub issue #1298.
    ignore_changes = [preload_data_config]
  }
}
```

### EventBridge Scheduler + Lambda for REDCap export to S3

```hcl
resource "aws_scheduler_schedule" "redcap_export" {
  name       = "redcap-nightly-export"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(0 2 * * ? *)"  # 02:00 UTC daily

  target {
    arn      = aws_lambda_function.redcap_exporter.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      redcap_url    = var.redcap_url
      output_bucket = aws_s3_bucket.ingestion.bucket
      output_prefix = "redcap-exports"
    })
  }
}

resource "aws_lambda_function" "redcap_exporter" {
  function_name = "redcap-to-s3-exporter"
  role          = aws_iam_role.lambda_redcap.arn
  runtime       = "python3.12"
  handler       = "handler.main"
  timeout       = 300
  memory_size   = 512
  filename      = data.archive_file.redcap_exporter.output_path

  environment {
    variables = {
      REDCAP_TOKEN_SECRET_ARN = aws_secretsmanager_secret.redcap_token.arn
      OUTPUT_BUCKET           = aws_s3_bucket.ingestion.bucket
      OUTPUT_PREFIX           = "redcap-exports"
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda Python pseudocode (not HCL):
# import boto3, requests, os, json
# from datetime import datetime
#
# def main(event, context):
#     secret = boto3.client('secretsmanager').get_secret_value(
#         SecretId=os.environ['REDCAP_TOKEN_SECRET_ARN'])
#     token = json.loads(secret['SecretString'])['token']
#
#     resp = requests.post(event['redcap_url'] + '/api/index.php', data={
#         'token': token,
#         'content': 'record',
#         'format': 'csv',
#         'type': 'flat',
#         'rawOrLabel': 'raw',
#     })
#     resp.raise_for_status()
#
#     key = f"{event['output_prefix']}/{datetime.utcnow().strftime('%Y/%m/%d/%H%M%S')}.csv"
#     boto3.client('s3').put_object(
#         Bucket=event['output_bucket'], Key=key,
#         Body=resp.content,
#         ServerSideEncryption='aws:kms')
```

### StartFHIRImportJob with Data Transformation Profile (CLI, orchestrated by Lambda)

```bash
# Composite: transform CSV + ingest into HealthLake in one step
aws healthlake start-fhir-import-job \
  --region us-east-1 \
  --datastore-id "${DATASTORE_ID}" \
  --input-data-config "S3Uri=s3://${INGESTION_BUCKET}/redcap-exports/2026/09/27/" \
  --job-output-data-config "{\"S3Configuration\":{\"S3Uri\":\"s3://${OUTPUT_BUCKET}/import-output/\",\"KmsKeyId\":\"${KMS_KEY_ARN}\"}}" \
  --data-access-role-arn "${DATA_ACCESS_ROLE_ARN}" \
  --profile-id "${CSV_TRANSFORMATION_PROFILE_ID}" \
  --input-format "CSV" \
  --drift-detection-enabled \
  --provenance-enabled \
  --job-name "redcap-import-$(date +%Y%m%d)" \
  --client-token "import-$(date +%s)"
```

### Standalone DTA Bulk Job to S3 (then import separately)

```bash
aws healthlake start-data-transformation-job \
  --region us-east-1 \
  --profile-id "${CSV_PROFILE_ID}" \
  --input-data-config "{\"S3Uri\":\"s3://${INGESTION_BUCKET}/redcap-exports/\",\"SourceFormat\":\"CSV\"}" \
  --output-data-config "{\"S3Configuration\":{\"S3Uri\":\"s3://${FHIR_STAGING_BUCKET}/fhir-ndjson/\",\"KmsKeyId\":\"${KMS_KEY_ARN}\"}}" \
  --data-access-role-arn "${DATA_ACCESS_ROLE_ARN}" \
  --drift-detection-enabled \
  --job-name "redcap-dta-$(date +%Y%m%d)"
```

### Iceberg table in Terraform

```hcl
resource "aws_glue_catalog_database" "fhir" {
  name = "fhir_registry"
}

resource "aws_glue_catalog_table" "patient" {
  name          = "patient"
  database_name = aws_glue_catalog_database.fhir.name
  table_type    = "EXTERNAL_TABLE"

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = 2
    }
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.analytics.bucket}/fhir/patient/"
    input_format  = "org.apache.hadoop.mapred.FileInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "id"
      type = "string"
    }
    columns {
      name    = "birth_date"
      type    = "date"
      comment = "FHIR Patient.birthDate"
    }
    columns {
      name = "gender"
      type = "string"
    }
    columns {
      name = "family_name"
      type = "string"
    }
  }

  parameters = {
    "classification"       = "parquet"
    "table_type"           = "ICEBERG"
    "format"               = "parquet"
    "write_target_data_file_size_bytes"          = "536870912"
    "optimize_rewrite_delete_file_threshold"     = "10"
    "vacuum_min_snapshots_to_keep"               = "5"
    "vacuum_max_snapshot_age_seconds"            = "604800"  # 7 days
  }
}
```

---

## Modular Terraform Structure

Recommended directory layout for this pipeline:

```
infrastructure/
  modules/
    ingestion/          # REDCap → S3
      main.tf           # Lambda, EventBridge Scheduler, S3 ingestion bucket
      variables.tf
      outputs.tf
      iam.tf
    transformation/     # HealthLake DTA profile + import job orchestration
      main.tf           # Step Functions state machine, Lambda for job polling
      variables.tf
      outputs.tf
      iam.tf
    persistence/        # HealthLake FHIR datastore
      main.tf           # awscc_healthlake_fhir_datastore, KMS, VPC endpoint
      variables.tf
      outputs.tf
      iam.tf
    analytics/          # Athena, Glue, Lake Formation
      main.tf           # aws_glue_catalog_database, aws_glue_catalog_table (Iceberg)
      variables.tf
      outputs.tf
      athena.tf         # aws_athena_workgroup, aws_athena_database
      lakeformation.tf  # aws_lakeformation_resource, aws_lakeformation_permissions
    visualization/      # QuickSight
      main.tf           # aws_quicksight_data_source, aws_quicksight_data_set
      variables.tf
      outputs.tf
    ml/                 # SageMaker
      main.tf           # aws_sagemaker_domain, aws_sagemaker_user_profile
      variables.tf
      outputs.tf
    security/           # Shared security primitives
      main.tf           # aws_kms_key, aws_cloudtrail, aws_vpc, VPC endpoints
      variables.tf
      outputs.tf
  environments/
    dev/
      main.tf           # calls modules with dev-sized configs
      versions.tf
      terraform.tfvars
    prod/
      main.tf           # calls modules with prod configs, stricter security
      versions.tf
      terraform.tfvars
```

**Provider version pinning** (required):

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.9"
    }
  }

  backend "s3" {
    bucket         = "clinical-registry-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-state-key"
    dynamodb_table = "clinical-registry-tflock"
  }
}
```

**Module calling pattern** (root `main.tf`):

```hcl
module "security" {
  source      = "../../modules/security"
  environment = var.environment
  region      = var.region
}

module "ingestion" {
  source          = "../../modules/ingestion"
  environment     = var.environment
  kms_key_arn     = module.security.kms_key_arn
  vpc_id          = module.security.vpc_id
  private_subnets = module.security.private_subnet_ids
  redcap_url      = var.redcap_url
}

module "persistence" {
  source          = "../../modules/persistence"
  environment     = var.environment
  kms_key_arn     = module.security.kms_key_arn
  vpc_id          = module.security.vpc_id
  private_subnets = module.security.private_subnet_ids
  datastore_name  = var.datastore_name
}

module "transformation" {
  source             = "../../modules/transformation"
  datastore_id       = module.persistence.datastore_id
  ingestion_bucket   = module.ingestion.bucket_name
  output_bucket_arn  = module.persistence.output_bucket_arn
  kms_key_arn        = module.security.kms_key_arn
}

module "analytics" {
  source          = "../../modules/analytics"
  fhir_bucket_arn = module.persistence.fhir_export_bucket_arn
  kms_key_arn     = module.security.kms_key_arn
}
```

---

## Gotchas & Warnings

### HealthLake

1. **`awscc_healthlake_fhir_datastore` forced replacement bug**: The `preload_data_config` attribute shows as "known after apply" on every plan, triggering forced replacement even when no configuration has changed. Workaround: add `lifecycle { ignore_changes = [preload_data_config] }`. This is a known provider bug (GitHub issue #1298, opened Nov 2023, not fully resolved).

2. **All properties require Replacement**: `DatastoreName`, `DatastoreTypeVersion`, `SseConfiguration`, `PreloadDataConfig`, and `IdentityProviderConfiguration` all require destroy+recreate. Plan your datastore configuration carefully before first apply — changing encryption type or name destroys the datastore and all data.

3. **FHIR R4 only**: HealthLake does not support FHIR R5. All pipeline output must be FHIR R4 compliant.

4. **Data Transformation Agent is Preview**: `start-data-transformation-job` and `update-profile-with-agent` APIs are subject to change before GA. Do not build production pipelines on the Agent AI conversational features without confirming readiness with the AWS account team.

5. **Integrated NLP requires Support ticket**: You cannot enable Comprehend Medical NLP integration via Terraform or CLI. It requires an AWS Support case.

6. **No `aws_healthlake_*` in `hashicorp/aws` provider**: The standard `aws` provider does not have HealthLake resources. Use `hashicorp/awscc`. There is no Terraform resource for import jobs — those are orchestrated programmatically (Lambda/Step Functions calling the SDK).

### Athena + Iceberg

7. **Lake Formation + Iceberg DDL conflict**: Athena cannot execute DDL operations (CREATE TABLE, ALTER TABLE) on Iceberg tables that are registered under Lake Formation governance. Register S3 locations in Lake Formation for access control, but create Iceberg tables from Terraform (Glue catalog) before registering the location, or use Athena CREATE TABLE DDL from outside the Lake Formation scope.

8. **`open_table_format_input` on existing tables causes data loss**: Adding this block to an already-existing `aws_glue_catalog_table` resource will destroy and recreate the table. Include it from the initial creation.

9. **Iceberg table parameters drift**: GitHub issues #33370 and #39010 report that Glue table `parameters` are removed or ignored after certain operations. Pin the `parameters` block explicitly and use `lifecycle { ignore_changes = [parameters] }` if drift is observed with read-only parameters added by AWS.

### Comprehend Medical

10. **No Terraform resources for Comprehend Medical APIs**: The `hashicorp/aws` provider has `aws_comprehend_document_classifier` and `aws_comprehend_entity_recognizer` but these are for custom model training, not for the medical entity detection APIs (`DetectEntitiesV2`, `InferICD10CM`, `InferRxNorm`, `InferSNOMEDCT`). Invocation of these APIs is managed by application code in Lambda, not by Terraform.

### QuickSight

11. **QuickSight account must pre-exist**: Terraform cannot create a QuickSight subscription/account. The QuickSight account must be subscribed via the AWS Console or API before any `aws_quicksight_*` resources can be applied. `aws_quicksight_account_subscription` resource exists but behavior varies by account state.

12. **QuickSight IAM identity mode vs IAM Identity Center**: For HIPAA deployments, QuickSight Enterprise Edition with IAM Identity Center provides better access controls. Standard IAM mode with `aws_quicksight_user` resource management is simpler but less scalable.

### REDCap Integration

13. **No native AWS service for REDCap**: REDCap has no direct AWS connector. All integration is via Lambda calling the REDCap API. The REDCap API token is a long-lived secret — store in AWS Secrets Manager and rotate on a schedule (REDCap also supports token rotation via API).

14. **REDCap on FHIR (CDIS) is for data ingestion INTO REDCap, not export**: The built-in REDCap on FHIR module pulls EHR data into REDCap. It does not export REDCap forms as FHIR. For exporting REDCap data as FHIR, use the HealthLake DTA CSV profile or a custom Lambda mapper.

### HIPAA

15. **BAA cannot be automated**: AWS Business Associate Agreement must be accepted manually in AWS Artifact. This is a legal prerequisite before using HealthLake or any HIPAA-eligible service with PHI.

16. **HealthLake data at rest is always encrypted**: The SSE configuration is required. If `cmk_type = "AWS_OWNED_KMS_KEY"`, AWS manages the key. If `cmk_type = "CUSTOMER_MANAGED_KMS_KEY"`, you must grant the HealthLake service principal (`healthlake.amazonaws.com`) `kms:GenerateDataKey`, `kms:Decrypt`, and `kms:DescribeKey` in the KMS key policy.

17. **SageMaker VpcOnly mode**: For HIPAA, `app_network_access_type = "VpcOnly"` is required. This means SageMaker needs NAT Gateway or VPC endpoints for ECR, S3, and SageMaker API service endpoints. Without these, SageMaker Studio will fail to start.

> ⚠️ **[TENTATIVE — unofficial source]** The themomentum.ai blog and factualminds.com blog provide Terraform HIPAA examples that are broadly consistent with AWS documentation, but have not been reviewed against the full HIPAA Security Rule checklist. The KMS key policy, S3 bucket policy, and CloudTrail examples extracted from factualminds.com are structurally sound but should be validated against your organization's compliance requirements before use in production.

---

## Verification Results

_Verified by Research Verifier agent on 2026-09-27. Each distinct factual claim from the findings above is assessed below._

---

### Claim: Data Transformation Agent is in Preview as of the research date
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation.html
- **Notes**: The official AWS HealthLake documentation carries an explicit "Important" notice: "Data Transformation Agent is available as a preview capability and is subject to change. The APIs, features, and documentation described in this guide may be modified before general availability." The March 2026 announcement page also labels the feature as Preview. No GA announcement was found as of the verification date (2026-09-27).

---

### Claim: HealthLake is managed via the `awscc` Terraform provider, not `hashicorp/aws`
- **Verdict**: ✅ CONFIRMED
- **Source**: https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/healthlake_fhir_datastore ; https://www.hashicorp.com/en/blog/aws-and-awscc-terraform-providers-better-together
- **Notes**: Confirmed that `awscc_healthlake_fhir_datastore` is the correct resource and it lives in the `hashicorp/awscc` provider. There is no `aws_healthlake_*` resource in the standard `hashicorp/aws` provider. The awscc provider auto-generates resources from CloudFormation schemas, which is how HealthLake is covered.

---

### Claim: `awscc_healthlake_fhir_datastore` forced replacement bug (GitHub issue #1298) is not fully resolved
- **Verdict**: ✅ CONFIRMED (issue is closed but the underlying behavior is by-design per CloudFormation schema)
- **Source**: https://github.com/hashicorp/terraform-provider-awscc/issues/1298 ; https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-healthlake-fhirdatastore.html
- **Notes**: GitHub issue #1298 is marked closed, but the forced-replacement behavior for `preload_data_config` is not a bug that was patched — it reflects the underlying CloudFormation schema, which marks `PreloadDataConfig` as "Update requires: Replacement." The `lifecycle { ignore_changes = [preload_data_config] }` workaround documented in the research remains the correct mitigation. The issue being "closed" does not mean the behavior changed; it means the provider team acknowledged it is schema-driven and not fixable at the provider layer.

---

### Claim: HealthLake supported regions are us-east-1, us-east-2, us-west-2, ap-south-1 only
- **Verdict**: ❌ CORRECTED
- **What is actually correct**: As of mid-2026 the service is available in eight regions: us-east-1, us-east-2, us-west-2, ap-south-1 (Mumbai), ap-southeast-2 (Sydney), ca-central-1 (Canada Central), eu-west-1 (Ireland), and eu-west-2 (London). Europe (Ireland) was added in June 2025; Europe (London) and Asia Pacific (Sydney) and Canada (Central) are also listed in the official endpoints table.
- **Source**: https://docs.aws.amazon.com/general/latest/gr/Amazon-HealthLake.html ; https://aws.amazon.com/about-aws/whats-new/2025/06/aws-healthlake-europe-ireland-region/
- **Notes**: The research document's region list (Section 1) is significantly out of date. Planners targeting European or Australian customers now have additional region options. The four regions listed in the research were correct as of approximately mid-2023 but are incomplete today.

---

### Claim: All HealthLake datastore properties (DatastoreName, DatastoreTypeVersion, PreloadDataConfig, SseConfiguration, IdentityProviderConfiguration) require Replacement; only Tags can be updated in place
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-healthlake-fhirdatastore.html
- **Notes**: The CloudFormation reference explicitly marks DatastoreName, DatastoreTypeVersion, IdentityProviderConfiguration, PreloadDataConfig, and SseConfiguration all as "Update requires: Replacement." Tags is the only property marked "Update requires: No interruption." The research accurately reflects this.

---

### Claim: HealthLake FHIR version is R4 only; no R5 support
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-healthlake-fhirdatastore.html ; https://docs.aws.amazon.com/healthlake/latest/devguide/what-is.html
- **Notes**: The CloudFormation schema shows `DatastoreTypeVersion` Allowed values: `R4` only. Multiple searches found no announcement of R5 support. Focus remains on R4 enhancements.

---

### Claim: Integrated NLP requires an AWS Support ticket to enable; it is not Terraform-configurable
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/healthlake/latest/devguide/integrated-medical-nlp.html
- **Notes**: The official documentation states verbatim: "Integrated NLP for HealthLake is turned off by default. To have it turned on, submit a support case using AWS Support Center Console." No CLI, SDK, or Terraform parameter exists to enable it. The research claim is accurate.

---

### Claim: Integrated NLP calls DetectEntities-V2, InferICD10-CM, and InferRxNorm; generates Condition and Observation resources linked via Linkage resource
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/healthlake/latest/devguide/integrated-medical-nlp.html
- **Notes**: The official documentation matches the research exactly on the three API calls and the resource generation logic (SIGN/SYMPTOM/DIAGNOSIS traits trigger Condition and Observation creation, linked via a Linkage resource).

---

### Claim: NLP-derived resources can be queried via Athena (SQL) but NOT via FHIR API search parameters
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/healthlake/latest/devguide/integrated-medical-nlp.html
- **Notes**: The documentation states: "Although GET requests are supported for FHIR resources generated by HealthLake integrated NLP, FHIR API search functionality is not." Athena SQL querying is confirmed as the alternative path.

---

### Claim: Athena does not support DDL operations on Iceberg tables registered with Lake Formation
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- **Notes**: The official Athena Iceberg documentation states under "Considerations and limitations": "Tables registered with Lake Formation — Athena does not currently support DDL operations on Iceberg tables that are registered with Lake Formation." The research claim is accurate.

---

### Claim: Lake Formation row/cell filters on Iceberg tables cause AccessDeniedException on metadata tables ($partitions, $files, $manifests, $snapshots)
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- **Notes**: The official documentation explicitly lists this under "Iceberg restricted metadata": "queries to $partitions, $files, $manifests, and $snapshots Iceberg metadata tables fail with an AccessDeniedException error" when Lake Formation row or cell filters are present. The research is accurate.

---

### Claim: Lake Formation cannot manage VACUUM, MERGE, UPDATE, or OPTIMIZE operations on Iceberg tables
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- **Notes**: Documented verbatim in the official Iceberg limitations: "you cannot use Lake Formation to manage permissions for operations like VACUUM, MERGE, UPDATE or OPTIMIZE with these table formats."

---

### Claim: Athena Engine v3 supports Apache Iceberg 1.4.2 and creates v2 tables
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- **Notes**: Official docs confirm: "Athena supports Apache Iceberg version 1.4.2" and "Athena only creates and operates on Iceberg v2 tables." Both facts in the research are accurate.

---

### Claim: Supported Iceberg file formats are Parquet, ORC, and Avro (Engine v3)
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- **Notes**: The limitations section of the Athena Iceberg docs lists exactly these three formats under "Supported file formats — Athena engine version 3 supports the following Iceberg file formats: Parquet, ORC, Avro."

---

### Claim: ALTER TABLE SET LOCATION is not supported for Iceberg tables
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/athena/latest/ug/querying-iceberg.html
- **Notes**: Listed explicitly under "Unsupported operations" in the Athena Iceberg documentation.

---

### Claim: Sync conversion endpoint is REST-only, not exposed as a CLI/SDK command; size limit is 1 MB per request
- **Verdict**: ✅ CONFIRMED (with a nuance on the size limit)
- **Source**: https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-features.html
- **Notes**: The documentation confirms the REST-only constraint: "The operation is available through the REST API only: it is not exposed as an AWS CLI or SDK command." On size limits, the official docs state: "Synchronous transform accepts C-CDA inputs up to 1 MB and combined CSV inputs up to 1 MB per request." The research states "1 MB per request" which is correct for C-CDA; for CSV the 1 MB limit applies to the combined size of all CSV files. The service quotas page also confirms the C-CDA sync limit is 1 MB (adjustable) and CSV sync limit is 500 KB combined (also adjustable). The research's "1 MB" figure is slightly imprecise for the CSV case — the default CSV sync limit is 500 KB, not 1 MB — but the statement is broadly correct for C-CDA. Planners should consult the quotas page for per-format details.

---

### Claim: Provenance is enabled by default; generates US Core-conformant FHIR Provenance resource with SHA-1 checksum
- **Verdict**: ✅ CONFIRMED
- **Source**: https://docs.aws.amazon.com/healthlake/latest/devguide/data-transformation-features.html
- **Notes**: Documentation confirms: "Provenance is enabled by default; set ProvenanceEnabled to false to disable it." The Provenance resource records "the source file URI and checksum" and "conform[s] to the US Core Provenance profile." The SHA-1 checksum reference is also confirmed in the documentation.

---

### Claim: REDCap API export formats are JSON (default), CSV, and XML (including CDISC ODM flavor)
- **Verdict**: ✅ CONFIRMED
- **Source**: https://bdeveer.github.io/REDCap_KB_RAG/RC-API-01_REDCap-API/ (semi-official community KB); corroborated by multiple REDCap API client library documentation sources
- **Notes**: No single official Vanderbilt REDCap API page is publicly accessible without authentication, but the three-format claim (JSON, CSV, XML/CDISC ODM) is consistent across all REDCap API client documentation (PyCap, redcapAPI R package, REDCapExporter). The CDISC ODM XML flavor is well-documented. The research label of "semi-official" for the KB source is appropriate.

---

### Claim: SageMaker VpcOnly mode requires VPC endpoints for ECR, S3, and SageMaker API service endpoints, or a NAT gateway
- **Verdict**: ✅ CONFIRMED (with a minor scope correction)
- **Source**: https://docs.aws.amazon.com/en_en/sagemaker/latest/dg/studio-updated-and-internet-access.html
- **Notes**: The official SageMaker Studio documentation confirms that in VpcOnly mode, SageMaker Studio requires either a NAT gateway or interface VPC endpoints for: SageMaker API (`com.amazonaws.{region}.sagemaker.api`), SageMaker AI runtime (`com.amazonaws.{region}.sagemaker.runtime`), Amazon S3, SageMaker Projects (`com.amazonaws.{region}.servicecatalog`), and SageMaker Studio (`aws.sagemaker.{region}.studio`). ECR is not listed as a required VPC endpoint for Studio itself (it is required for training jobs using the SageMaker Python SDK). The research claim mentions ECR as one of the required endpoints, which is slightly overbroad for Studio specifically, but is correct if the domain is used for training jobs. The core warning that "SageMaker Studio will fail to start" without these endpoints is accurate.

---

### Claim: `app_security_group_management` is required in VpcOnly mode
- **Verdict**: ❌ CORRECTED
- **What is actually correct**: `AppSecurityGroupManagement` is NOT universally required in VpcOnly mode. Per the official CloudFormation documentation, it is "Required: No" and is specifically required only when `CreateDomain.AppNetworkAccessType` is `VpcOnly` AND `DomainSettings.RStudioServerProDomainSettings.DomainExecutionRoleArn` is also provided (i.e., when RStudio Server Pro is configured). For a plain VpcOnly domain without RStudio, this parameter is optional.
- **Source**: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-sagemaker-domain.html
- **Notes**: The research states "`app_security_group_management`: `Service` or `Customer` — required in `VpcOnly` mode," which overstates the requirement. It is only required when RStudio Server Pro is also configured. Planners should include it if using RStudio, but should not treat it as universally mandatory for VpcOnly deployments.

---

### Claim: QuickSight account must be pre-subscribed; Terraform cannot create a QuickSight subscription
- **Verdict**: ❌ CORRECTED (partially — the claim is outdated)
- **What is actually correct**: The `aws_quicksight_account_subscription` Terraform resource does exist in the `hashicorp/aws` provider and can be used to create a QuickSight subscription programmatically. The research acknowledges this resource exists but then says "behavior varies by account state" and implies console/API setup is required. In practice, `aws_quicksight_account_subscription` can provision a new QuickSight account via Terraform. However, a real limitation exists: when creating a subscription via the API (including Terraform), QuickSight does not automatically create the `aws-quicksight-service-role-v0` IAM role, so S3 access policies may need to be set up separately. The research's blanket statement that "Terraform cannot create a QuickSight subscription/account" is incorrect — the resource exists and works, but with caveats around IAM role creation.
- **Source**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/quicksight_account_subscription ; https://discuss.hashicorp.com/t/quicksight-subscription-and-automatic-quicksight-service-role-creation/53718
- **Notes**: The Gotchas section (item 11) should be updated to note that `aws_quicksight_account_subscription` can create the subscription, but that the QuickSight service role may need to be created separately when using the API/Terraform path rather than the console.

---

### Claim: No `aws_comprehend_medical_*` Terraform resources exist; only `aws_comprehend_document_classifier` and `aws_comprehend_entity_recognizer` exist (for custom models)
- **Verdict**: ✅ CONFIRMED
- **Source**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/comprehend_entity_recognizer
- **Notes**: Confirmed that there are no Terraform resources for the Comprehend Medical detection APIs. The two resources named in the research (`aws_comprehend_document_classifier` and `aws_comprehend_entity_recognizer`) are for custom model training, not for the medical NLP detection APIs. This is accurate.

---

### Claim: The sync conversion endpoint URL is `POST https://datatransformation.healthlake.<region>.amazonaws.com/transform-data`
- **Verdict**: 🔍 UNVERIFIABLE
- **Attempts made**: (1) Searched for the exact sync endpoint URL format in AWS HealthLake documentation. (2) Fetched the data-transformation-features page which confirms the sync endpoint exists and is REST-only, but does not print the full endpoint URL in the fetched content.
- **Recommendation**: Treat as TENTATIVE. The existence of a REST-only sync endpoint is confirmed; the exact hostname pattern should be validated against the AWS HealthLake API reference or the Getting Started CLI guide before use in production code.

---

### Claim: REDCap on FHIR (CDIS module) pulls EHR data INTO REDCap and does NOT export REDCap data as FHIR
- **Verdict**: ✅ CONFIRMED
- **Source**: https://mitre.github.io/fhir-for-research/modules/redcap-fhir (MITRE FHIR for Research guide, semi-official)
- **Notes**: This is well-established in the REDCap/FHIR community. The CDIS module is an EHR-to-REDCap ingest tool, not a REDCap-to-FHIR export tool. Multiple authoritative community sources corroborate this directional distinction.

---

### Summary

**Claims verified (CONFIRMED + CORRECTED + DEPRECATED)**: 20 out of 21 claims assessed
**Claims remaining UNVERIFIABLE**: 1 (sync endpoint URL format)

**Items requiring particular caution:**

1. **CORRECTED — HealthLake supported regions**: The research lists only four regions (us-east-1, us-east-2, us-west-2, ap-south-1). The actual count as of September 2026 is eight regions, adding ap-southeast-2, ca-central-1, eu-west-1, and eu-west-2. Any region-selection logic, cost modeling, or data-residency planning should use the updated list from https://docs.aws.amazon.com/general/latest/gr/Amazon-HealthLake.html.

2. **CORRECTED — `app_security_group_management` is not universally required in VpcOnly mode**: The research implies this is always required when using VpcOnly. Official CloudFormation docs show it is only required when RStudio Server Pro is also configured. Applying it unconditionally is harmless but the stated justification ("required in VpcOnly mode") is incorrect and may cause confusion.

3. **CORRECTED — QuickSight subscription can be created via Terraform**: The research's statement that "Terraform cannot create a QuickSight subscription/account" is incorrect. The `aws_quicksight_account_subscription` resource exists and works. The real caveat is that the QuickSight service IAM role is not auto-created when using the API path, requiring additional manual or Terraform-managed IAM work.

4. **TENTATIVE — Sync endpoint URL**: The exact hostname `datatransformation.healthlake.<region>.amazonaws.com` was not independently confirmed from official documentation during verification. Validate before embedding in production code.

5. **TENTATIVE — `awscc_healthlake_fhir_datastore` forced replacement bug status**: GitHub issue #1298 is closed, but the behavior is by-design per the CloudFormation schema. The `lifecycle { ignore_changes = [preload_data_config] }` workaround remains necessary and correct. The "not fully resolved" characterization in the research is accurate in practical terms.
