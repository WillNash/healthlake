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
    sid    = "AllowS3PutObject"
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.landing.arn}/*"]
  }

  statement {
    sid    = "AllowSecretsManagerGetToken"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [aws_secretsmanager_secret.redcap_token.arn]
  }

  statement {
    sid    = "AllowKmsForLandingBucketAndEnvVars"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [var.kms_key_arn]
  }

  statement {
    sid    = "AllowSqsSendMessageToDlq"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
    ]
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
    sid    = "AllowInvokeLambda"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [aws_lambda_function.redcap_exporter.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_inline" {
  name   = "scheduler-invoke-lambda"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_inline.json
}
