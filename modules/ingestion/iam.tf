data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "AllowLambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redcap_exporter" {
  name               = "${var.project_name}-${var.environment}-redcap-exporter"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "redcap_exporter_inline" {
  statement {
    sid     = "AllowS3PutObject"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.landing.arn}/*"]
  }

  statement {
    sid     = "AllowSecretsManagerGetToken"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    # Wildcard scoped to this project+environment — covers all per-project secrets.
    resources = ["arn:aws:secretsmanager:*:*:secret:/${var.project_name}/${var.environment}/redcap-api-token/*"]
  }

  statement {
    sid     = "AllowKmsForLandingBucketAndEnvVars"
    effect  = "Allow"
    actions = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  statement {
    sid     = "AllowSqsSendMessageToDlq"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.redcap_exporter_dlq.arn]
  }
}

resource "aws_iam_role_policy" "redcap_exporter_inline" {
  name   = "redcap-exporter-inline"
  role   = aws_iam_role.redcap_exporter.id
  policy = data.aws_iam_policy_document.redcap_exporter_inline.json
}

resource "aws_iam_role_policy_attachment" "redcap_exporter_basic_execution" {
  role       = aws_iam_role.redcap_exporter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------------------------------------------------------------------------
# EventBridge Scheduler role
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    sid     = "AllowSchedulerAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.project_name}-${var.environment}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
}

data "aws_iam_policy_document" "scheduler_inline" {
  statement {
    sid     = "AllowInvokeLambda"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    # Wildcard scoped to this project+environment — covers all per-project exporter Lambdas.
    resources = ["arn:aws:lambda:*:*:function:${var.project_name}-${var.environment}-redcap-exporter-*"]
  }
}

resource "aws_iam_role_policy" "scheduler_inline" {
  name   = "scheduler-invoke-lambda"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_inline.json
}
