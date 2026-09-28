# ---------------------------------------------------------------------------
# S3 — access log bucket (created first so landing bucket can reference it)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "access_logs" {
  bucket_prefix = "${var.project_name}-${var.environment}-landing-logs-"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# S3 — landing bucket
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "landing" {
  bucket_prefix = "${var.project_name}-${var.environment}-landing-"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "landing" {
  bucket        = aws_s3_bucket.landing.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "landing-access-logs/"
}

resource "aws_s3_bucket_object_lock_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  rule {
    default_retention {
      mode  = "COMPLIANCE"
      years = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.landing]
}

resource "aws_s3_bucket_policy" "landing" {
  bucket = aws_s3_bucket.landing.id
  policy = data.aws_iam_policy_document.landing_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.landing]
}

data "aws_iam_policy_document" "landing_bucket_policy" {
  statement {
    sid    = "DenyHTTP"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.landing.arn,
      "${aws_s3_bucket.landing.arn}/*",
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
    resources = ["${aws_s3_bucket.landing.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

resource "aws_s3_bucket_notification" "landing" {
  bucket      = aws_s3_bucket.landing.id
  eventbridge = true
}

# ---------------------------------------------------------------------------
# Secrets Manager — REDCap API token
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "redcap_token" {
  name       = "/${var.project_name}/${var.environment}/redcap-api-token"
  kms_key_id = var.kms_key_arn

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "placeholder" {
  secret_id     = aws_secretsmanager_secret.redcap_token.id
  secret_string = jsonencode({ token = "REPLACE_ME" })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ---------------------------------------------------------------------------
# SQS DLQ — Lambda failure destination
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "redcap_exporter_dlq" {
  name                       = "${var.project_name}-${var.environment}-redcap-exporter-dlq"
  kms_master_key_id          = var.kms_key_arn
  message_retention_seconds  = 1209600 # 14 days
}

# ---------------------------------------------------------------------------
# Lambda — REDCap exporter
# ---------------------------------------------------------------------------

data "archive_file" "redcap_exporter" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/redcap_exporter"
  output_path = "${path.module}/lambda/redcap_exporter.zip"
}

resource "aws_lambda_function" "redcap_exporter" {
  function_name = "${var.project_name}-${var.environment}-redcap-exporter"
  role          = aws_iam_role.redcap_exporter.arn

  filename         = data.archive_file.redcap_exporter.output_path
  source_code_hash = data.archive_file.redcap_exporter.output_base64sha256

  runtime                        = "python3.12"
  architectures                  = ["arm64"]
  handler                        = "handler.lambda_handler"
  timeout                        = 300
  memory_size                    = 512
  reserved_concurrent_executions = 1

  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      LANDING_BUCKET     = aws_s3_bucket.landing.id
      SECRET_ARN         = aws_secretsmanager_secret.redcap_token.arn
      REDCAP_URL         = var.redcap_url
      REDCAP_PROJECT_ID  = var.redcap_project_id
      PAGE_SIZE          = tostring(var.redcap_page_size)
      KMS_KEY_ARN        = var.kms_key_arn
    }
  }

}

resource "aws_lambda_function_event_invoke_config" "redcap_exporter" {
  function_name          = aws_lambda_function.redcap_exporter.function_name
  maximum_retry_attempts = 0

  destination_config {
    on_failure {
      destination = aws_sqs_queue.redcap_exporter_dlq.arn
    }
  }
}

# ---------------------------------------------------------------------------
# EventBridge Scheduler — nightly REDCap export trigger
# ---------------------------------------------------------------------------

resource "aws_scheduler_schedule_group" "main" {
  name = "${var.project_name}-${var.environment}"
}

resource "aws_scheduler_schedule" "redcap_export" {
  name       = "redcap-export"
  group_name = aws_scheduler_schedule_group.main.name

  schedule_expression = var.export_schedule_expression

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.redcap_exporter.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
