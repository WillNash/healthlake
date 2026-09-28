data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "quicksight_trust" {
  statement {
    sid     = "AllowQuickSightService"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["quicksight.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "quicksight_service" {
  # S3 access — analytics bucket
  statement {
    sid    = "S3AnalyticsBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.analytics_bucket_arn,
      "${var.analytics_bucket_arn}/*",
    ]
  }

  # S3 access — Athena results bucket
  statement {
    sid    = "S3AthenaResultsBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.athena_results_bucket_arn,
      "${var.athena_results_bucket_arn}/*",
    ]
  }

  # Athena — scoped to the specific workgroup
  statement {
    sid    = "AthenaWorkgroupAccess"
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryResults",
      "athena:GetQueryExecution",
      "athena:StopQueryExecution",
    ]
    resources = [
      "arn:aws:athena:*:${data.aws_caller_identity.current.account_id}:workgroup/${var.athena_workgroup_name}",
    ]
  }

  # Glue — scoped to the FHIR catalog database
  statement {
    sid    = "GlueCatalogRead"
    effect = "Allow"
    actions = [
      "glue:GetTable",
      "glue:GetDatabase",
      "glue:GetPartition",
    ]
    resources = [
      "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}",
      "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*",
    ]
  }

  # KMS — decrypt/encrypt using the main CMK
  statement {
    sid    = "KMSDecryptGenerateDataKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role" "quicksight_service" {
  name               = "${var.project_name}-${var.environment}-quicksight-service"
  assume_role_policy = data.aws_iam_policy_document.quicksight_trust.json

  tags = {
    Name = "${var.project_name}-${var.environment}-quicksight-service"
  }
}

resource "aws_iam_role_policy" "quicksight_service" {
  name   = "quicksight-service-policy"
  role   = aws_iam_role.quicksight_service.id
  policy = data.aws_iam_policy_document.quicksight_service.json
}
