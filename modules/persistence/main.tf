# ---------------------------------------------------------------------------
# KMS key — dedicated to HealthLake and associated S3 buckets
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "healthlake_kms_policy" {
  statement {
    sid    = "EnableRootAccountPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowHealthLakeService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["healthlake.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "healthlake" {
  description             = "Dedicated CMK for HealthLake FHIR datastore and associated S3 buckets — ${var.project_name}/${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.healthlake_kms_policy.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "healthlake" {
  name          = "alias/${var.project_name}/${var.environment}/healthlake"
  target_key_id = aws_kms_key.healthlake.key_id
}

# ---------------------------------------------------------------------------
# HealthLake FHIR R4 datastore (awscc provider)
#
# CRITICAL: ALL properties except tags require destroy+recreate.
# Choose name, datastore_type_version, and sse_configuration carefully
# before first apply — changing any of them destroys all FHIR data.
# ---------------------------------------------------------------------------

resource "awscc_healthlake_fhir_datastore" "main" {
  count = var.healthlake_enabled ? 1 : 0

  datastore_name         = "${var.project_name}-${var.environment}"
  datastore_type_version = "R4"

  sse_configuration = {
    kms_encryption_config = {
      cmk_type   = "CUSTOMER_MANAGED_KMS_KEY"
      kms_key_id = aws_kms_key.healthlake.arn
    }
  }

  tags = [
    { key = "Project",     value = var.project_name },
    { key = "Environment", value = var.environment },
    { key = "ManagedBy",   value = "terraform" },
    { key = "HIPAA",       value = "true" },
  ]

  lifecycle {
    # preload_data_config always shows as "known after apply" even when unset —
    # a CloudFormation schema limitation. ignore_changes prevents forced replacement.
    ignore_changes = [preload_data_config]
  }
}

# ---------------------------------------------------------------------------
# S3 — FHIR export bucket (HealthLake bulk export target)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "fhir_export" {
  bucket_prefix = "${var.project_name}-${var.environment}-fhir-export-"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "fhir_export" {
  bucket = aws_s3_bucket.fhir_export.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fhir_export" {
  bucket = aws_s3_bucket.fhir_export.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.healthlake.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "fhir_export" {
  bucket = aws_s3_bucket.fhir_export.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "fhir_export" {
  bucket = aws_s3_bucket.fhir_export.id

  rule {
    default_retention {
      mode  = "GOVERNANCE"
      years = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.fhir_export]
}

resource "aws_s3_bucket_policy" "fhir_export" {
  bucket = aws_s3_bucket.fhir_export.id
  policy = data.aws_iam_policy_document.fhir_export_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.fhir_export]
}

data "aws_iam_policy_document" "fhir_export_bucket_policy" {
  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.fhir_export.arn,
      "${aws_s3_bucket.fhir_export.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyNonKmsPutObject"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.fhir_export.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

# ---------------------------------------------------------------------------
# S3 — import output bucket (DTA import job provenance / FHIR NDJSON output)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "import_output" {
  bucket_prefix = "${var.project_name}-${var.environment}-import-output-"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "import_output" {
  bucket = aws_s3_bucket.import_output.id

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "import_output" {
  bucket = aws_s3_bucket.import_output.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.healthlake.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "import_output" {
  bucket = aws_s3_bucket.import_output.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "import_output" {
  bucket = aws_s3_bucket.import_output.id
  policy = data.aws_iam_policy_document.import_output_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.import_output]
}

data "aws_iam_policy_document" "import_output_bucket_policy" {
  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.import_output.arn,
      "${aws_s3_bucket.import_output.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyNonKmsPutObject"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.import_output.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}
