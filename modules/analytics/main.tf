data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── S3: analytics bucket (Iceberg Parquet) ────────────────────────────────────

resource "aws_s3_bucket" "analytics" {
  bucket = "${var.project_name}-${var.environment}-analytics"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.analytics]
}

resource "aws_s3_bucket_public_access_block" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "analytics" {
  bucket = aws_s3_bucket.analytics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.analytics.arn,
          "${aws_s3_bucket.analytics.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyUnencryptedPuts"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.analytics.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# ── S3: Athena results ────────────────────────────────────────────────────────

resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-${var.environment}-athena-results"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyUnencryptedPuts"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.athena_results.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# ── S3: Glue scripts ──────────────────────────────────────────────────────────

resource "aws_s3_bucket" "glue_scripts" {
  bucket = "${var.project_name}-${var.environment}-glue-scripts"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "glue_scripts" {
  bucket = aws_s3_bucket.glue_scripts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.glue_scripts.arn,
          "${aws_s3_bucket.glue_scripts.arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })
}

# Upload Glue ETL script to S3
resource "aws_s3_object" "fhir_to_iceberg" {
  bucket = aws_s3_bucket.glue_scripts.id
  key    = "scripts/fhir_to_iceberg.py"
  source = "${path.module}/lambda/fhir_to_iceberg/fhir_to_iceberg.py"
  etag   = filemd5("${path.module}/lambda/fhir_to_iceberg/fhir_to_iceberg.py")
}

# ── Glue catalog database ─────────────────────────────────────────────────────

# This IS the Athena database — do NOT also create aws_athena_database.
# Athena reads from the Glue Data Catalog natively; a duplicate aws_athena_database
# would conflict with this resource.
resource "aws_glue_catalog_database" "fhir" {
  name = "fhir_registry_${var.environment}"
}

# ── Glue catalog tables (Iceberg v2) — for_each over fhir_resource_tables ────

resource "aws_glue_catalog_table" "fhir_resource" {
  for_each = toset(var.fhir_resource_tables)

  name          = each.key
  database_name = aws_glue_catalog_database.fhir.name
  table_type    = "EXTERNAL_TABLE"

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = 2
    }
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.analytics.bucket}/${each.key}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    # Common columns present on all FHIR resource tables.
    # The Glue ETL job writes the full schema; Iceberg schema evolution handles additions.
    columns {
      name    = "id"
      type    = "string"
      comment = "FHIR resource logical ID"
    }
    columns {
      name    = "meta_last_updated"
      type    = "timestamp"
      comment = "FHIR meta.lastUpdated"
    }
  }

  parameters = {
    "classification" = "parquet"
    "table_type"     = "ICEBERG"
  }

  lifecycle {
    # AWS adds Iceberg metadata parameters after creation causing spurious drift.
    ignore_changes = [parameters]
  }
}

# ── Glue ETL IAM role ─────────────────────────────────────────────────────────

resource "aws_iam_role" "glue_etl" {
  name = "${var.project_name}-${var.environment}-glue-etl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "GlueTrust"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_etl_service" {
  role       = aws_iam_role.glue_etl.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_etl" {
  name = "glue-etl-inline"
  role = aws_iam_role.glue_etl.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadFHIRExport"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          var.fhir_export_bucket_arn,
          "${var.fhir_export_bucket_arn}/*"
        ]
      },
      {
        Sid    = "WriteAnalytics"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.analytics.arn,
          "${aws_s3_bucket.analytics.arn}/*"
        ]
      },
      {
        Sid    = "ReadGlueScripts"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.glue_scripts.arn}/*"]
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:UpdateTable"
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.fhir.name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.fhir.name}/*"
        ]
      }
    ]
  })
}

# ── Glue job: fhir_to_iceberg ─────────────────────────────────────────────────

resource "aws_glue_job" "fhir_to_iceberg" {
  name         = "${var.project_name}-${var.environment}-fhir-to-iceberg"
  role_arn     = aws_iam_role.glue_etl.arn
  glue_version = "4.0"
  worker_type  = "G.1X"

  number_of_workers = var.glue_worker_count

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.glue_scripts.bucket}/scripts/fhir_to_iceberg.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"    = "job-bookmark-enable"
    "--enable-metrics"         = ""
    "--enable-job-insights"    = "true"
    "--fhir_export_bucket"     = var.fhir_export_bucket_name
    "--database_name"          = aws_glue_catalog_database.fhir.name
    "--analytics_bucket"       = aws_s3_bucket.analytics.bucket
  }
}

# ── Iceberg compaction role (bypasses Lake Formation) ─────────────────────────

resource "aws_iam_role" "iceberg_compaction" {
  name = "${var.project_name}-${var.environment}-iceberg-compaction"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "GlueTrust"
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "iceberg_compaction_service" {
  role       = aws_iam_role.iceberg_compaction.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "iceberg_compaction" {
  name = "iceberg-compaction-inline"
  role = aws_iam_role.iceberg_compaction.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AnalyticsReadWrite"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.analytics.arn,
          "${aws_s3_bucket.analytics.arn}/*"
        ]
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "GlueCatalog"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:UpdateTable"
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${aws_glue_catalog_database.fhir.name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.fhir.name}/*"
        ]
      }
    ]
  })
}
