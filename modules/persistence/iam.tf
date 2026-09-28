data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# HealthLake data access role — used as --data-access-role-arn in import jobs
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "healthlake_assume_role" {
  statement {
    sid     = "AllowHealthLakeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["healthlake.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "healthlake_data_access" {
  name               = "${var.project_name}-${var.environment}-healthlake-data-access"
  assume_role_policy = data.aws_iam_policy_document.healthlake_assume_role.json
}

data "aws_iam_policy_document" "healthlake_data_access_inline" {
  statement {
    sid    = "AllowReadLandingBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.landing_bucket_arn,
      "${var.landing_bucket_arn}/*",
    ]
  }

  statement {
    sid    = "AllowWriteImportOutputBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.import_output.arn,
      "${aws_s3_bucket.import_output.arn}/*",
    ]
  }

  statement {
    sid    = "AllowKmsForBuckets"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [aws_kms_key.healthlake.arn]
  }
}

resource "aws_iam_role_policy" "healthlake_data_access_inline" {
  name   = "healthlake-data-access-inline"
  role   = aws_iam_role.healthlake_data_access.id
  policy = data.aws_iam_policy_document.healthlake_data_access_inline.json
}

# ---------------------------------------------------------------------------
# HealthLake export role — used for bulk FHIR export jobs
# ---------------------------------------------------------------------------

resource "aws_iam_role" "healthlake_export" {
  name               = "${var.project_name}-${var.environment}-healthlake-export"
  assume_role_policy = data.aws_iam_policy_document.healthlake_assume_role.json
}

data "aws_iam_policy_document" "healthlake_export_inline" {
  statement {
    sid    = "AllowWriteFhirExportBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.fhir_export.arn,
      "${aws_s3_bucket.fhir_export.arn}/*",
    ]
  }

  statement {
    sid    = "AllowKmsForExportBucket"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [aws_kms_key.healthlake.arn]
  }
}

resource "aws_iam_role_policy" "healthlake_export_inline" {
  name   = "healthlake-export-inline"
  role   = aws_iam_role.healthlake_export.id
  policy = data.aws_iam_policy_document.healthlake_export_inline.json
}
