data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# SageMaker execution role — trust policy
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "sagemaker_trust" {
  statement {
    sid     = "AllowSageMakerService"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# SageMaker execution role and inline policy
#
# The inline policy uses jsonencode rather than a data source so that
# conditional ARN references (aws_s3_bucket.sagemaker[0].arn,
# aws_kms_key.sagemaker_efs[0].arn) are only resolved when the role resource
# itself is being created — i.e., when enable_sagemaker = true and the
# count-gated resource blocks below exist in state. Using a shared
# aws_iam_policy_document data source would force Terraform to resolve those
# references at plan time even when enable_sagemaker = false.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "sagemaker_execution" {
  count = var.enable_sagemaker ? 1 : 0

  name               = "${var.project_name}-${var.environment}-sagemaker-execution"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_trust.json

  tags = {
    Name = "${var.project_name}-${var.environment}-sagemaker-execution"
  }
}

resource "aws_iam_role_policy" "sagemaker_execution" {
  count = var.enable_sagemaker ? 1 : 0

  name = "sagemaker-execution-policy"
  role = aws_iam_role.sagemaker_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3AnalyticsBucketRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          var.analytics_bucket_arn,
          "${var.analytics_bucket_arn}/*",
        ]
      },
      {
        Sid    = "S3SagemakerBucketFullAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.sagemaker[0].arn,
          "${aws_s3_bucket.sagemaker[0].arn}/*",
        ]
      },
      {
        Sid    = "AthenaWorkgroupAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryResults",
          "athena:GetQueryExecution",
        ]
        Resource = [
          "arn:aws:athena:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workgroup/${var.athena_workgroup_name}",
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartition",
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*",
        ]
      },
      {
        Sid    = "KMSMainCMK"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "KMSSageMakerEFSCMK"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
        ]
        Resource = [aws_kms_key.sagemaker_efs[0].arn]
      },
    ]
  })
}
