# ── S3: FHIR staging bucket ───────────────────────────────────────────────────
# Holds FHIR NDJSON written by csv_to_fhir_mapper, consumed by HealthLake import.
# Transient — objects expire after 14 days.

resource "aws_s3_bucket" "fhir_staging" {
  bucket_prefix = "${var.project_name}-${var.environment}-fhir-staging-"
}

resource "aws_s3_bucket_versioning" "fhir_staging" {
  bucket = aws_s3_bucket.fhir_staging.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fhir_staging" {
  bucket = aws_s3_bucket.fhir_staging.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "fhir_staging" {
  bucket                  = aws_s3_bucket.fhir_staging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "fhir_staging" {
  bucket = aws_s3_bucket.fhir_staging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.fhir_staging.arn, "${aws_s3_bucket.fhir_staging.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      {
        Sid       = "DenyNonKmsPutObject"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.fhir_staging.arn}/*"
        Condition = { StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" } }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.fhir_staging]
}

resource "aws_s3_bucket_lifecycle_configuration" "fhir_staging" {
  bucket = aws_s3_bucket.fhir_staging.id

  rule {
    id     = "expire-ndjson"
    status = "Enabled"
    filter { prefix = "fhir-ndjson/" }
    expiration { days = 14 }
    noncurrent_version_expiration { noncurrent_days = 7 }
  }
}

# ── SNS: import failures ──────────────────────────────────────────────────────

resource "aws_sns_topic" "import_failures" {
  name              = "${var.project_name}-${var.environment}-import-failures"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_sns_topic_policy" "import_failures" {
  arn = aws_sns_topic.import_failures.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSFNPublish"
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.import_failures.arn
    }]
  })
}

# ── SQS: shared Lambda DLQ ───────────────────────────────────────────────────

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${var.project_name}-${var.environment}-transformation-dlq"
  kms_master_key_id         = var.kms_key_arn
  message_retention_seconds = 1209600
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "sfn_import" {
  name              = "/aws/states/${var.project_name}-${var.environment}-import-orchestrator"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "csv_to_fhir_mapper" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-csv-to-fhir-mapper"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "import_launcher" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-import-launcher"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "import_poller" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-import-poller"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "check_import_failures" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-check-import-failures"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

# ── Lambda archives ───────────────────────────────────────────────────────────

data "archive_file" "csv_to_fhir_mapper" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/csv_to_fhir_mapper"
  output_path = "${path.module}/lambda/csv_to_fhir_mapper.zip"
}

data "archive_file" "import_launcher" {
  type        = "zip"
  source_file = "${path.module}/lambda/import_launcher/handler.py"
  output_path = "${path.module}/lambda/import_launcher/handler.zip"
}

data "archive_file" "import_poller" {
  type        = "zip"
  source_file = "${path.module}/lambda/import_poller/handler.py"
  output_path = "${path.module}/lambda/import_poller/handler.zip"
}

data "archive_file" "check_import_failures" {
  type        = "zip"
  source_file = "${path.module}/lambda/check_import_failures/handler.py"
  output_path = "${path.module}/lambda/check_import_failures/handler.zip"
}

# ── Lambda: csv_to_fhir_mapper ────────────────────────────────────────────────

resource "aws_lambda_function" "csv_to_fhir_mapper" {
  function_name    = "${var.project_name}-${var.environment}-csv-to-fhir-mapper"
  role             = aws_iam_role.csv_to_fhir_mapper.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.csv_to_fhir_mapper.output_path
  source_code_hash = data.archive_file.csv_to_fhir_mapper.output_base64sha256
  timeout          = 300
  memory_size      = 256
  kms_key_arn      = var.kms_key_arn

  reserved_concurrent_executions = 5

  environment {
    variables = {
      FHIR_STAGING_BUCKET = aws_s3_bucket.fhir_staging.bucket
      REGISTRY_MAP        = jsonencode(var.registry_map)
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  depends_on = [aws_cloudwatch_log_group.csv_to_fhir_mapper]
}

# ── Lambda: import_launcher ───────────────────────────────────────────────────

resource "aws_lambda_function" "import_launcher" {
  function_name    = "${var.project_name}-${var.environment}-import-launcher"
  role             = aws_iam_role.import_launcher.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.import_launcher.output_path
  source_code_hash = data.archive_file.import_launcher.output_base64sha256
  timeout          = 60
  kms_key_arn      = var.kms_key_arn

  reserved_concurrent_executions = 10

  environment {
    variables = {
      DATASTORE_ID         = var.datastore_id
      IMPORT_OUTPUT_BUCKET = var.import_output_bucket_name
      KMS_KEY_ARN          = var.kms_key_arn
      DATA_ACCESS_ROLE_ARN = var.healthlake_data_access_role_arn
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  depends_on = [aws_cloudwatch_log_group.import_launcher]
}

# ── Lambda: import_poller ─────────────────────────────────────────────────────

resource "aws_lambda_function" "import_poller" {
  function_name    = "${var.project_name}-${var.environment}-import-poller"
  role             = aws_iam_role.import_poller.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.import_poller.output_path
  source_code_hash = data.archive_file.import_poller.output_base64sha256
  timeout          = 30
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = {
      DATASTORE_ID = var.datastore_id
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  depends_on = [aws_cloudwatch_log_group.import_poller]
}

# ── Lambda: check_import_failures ─────────────────────────────────────────────

resource "aws_lambda_function" "check_import_failures" {
  function_name    = "${var.project_name}-${var.environment}-check-import-failures"
  role             = aws_iam_role.check_import_failures.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.check_import_failures.output_path
  source_code_hash = data.archive_file.check_import_failures.output_base64sha256
  timeout          = 60
  kms_key_arn      = var.kms_key_arn

  environment {
    variables = {
      IMPORT_OUTPUT_BUCKET = var.import_output_bucket_name
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  depends_on = [aws_cloudwatch_log_group.check_import_failures]
}

# ── EventBridge: S3 landing CSV → Step Functions ──────────────────────────────

resource "aws_cloudwatch_event_rule" "s3_landing_csv" {
  name        = "${var.project_name}-${var.environment}-s3-landing-csv"
  description = "Fires when a REDCap CSV lands in the landing bucket."

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [var.landing_bucket_name] }
      object = { key = [{ prefix = "redcap-exports/" }] }
    }
  })
}

resource "aws_cloudwatch_event_target" "sfn" {
  rule      = aws_cloudwatch_event_rule.s3_landing_csv.name
  target_id = "ImportOrchestratorSFN"
  arn       = aws_sfn_state_machine.import_orchestrator.arn
  role_arn  = aws_iam_role.events_to_sfn.arn
}

# ── Step Functions: import orchestrator ──────────────────────────────────────

resource "aws_sfn_state_machine" "import_orchestrator" {
  name     = "${var.project_name}-${var.environment}-import-orchestrator"
  type     = "STANDARD"
  role_arn = aws_iam_role.sfn.arn

  encryption_configuration {
    kms_key_id                        = var.kms_key_arn
    type                              = "CUSTOMER_MANAGED_KMS_KEY"
    kms_data_key_reuse_period_seconds = 300
  }

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.sfn_import.arn}:*"
  }

  definition = jsonencode({
    Comment = "Convert REDCap CSV to FHIR NDJSON and import into HealthLake."
    StartAt = "MapCSVToFHIR"
    States = {

      MapCSVToFHIR = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.csv_to_fhir_mapper.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.mapper_result"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "LaunchImportJob"
      }

      LaunchImportJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.import_launcher.arn
          "Payload.$"  = "$.mapper_result.Payload"
        }
        ResultPath = "$.import_result"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "WaitForImport"
      }

      WaitForImport = {
        Type    = "Wait"
        Seconds = 60
        Next    = "PollImportStatus"
      }

      PollImportStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.import_poller.arn
          "Payload.$"  = "$.import_result.Payload"
        }
        ResultPath = "$.poll_result"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "CheckImportStatus"
      }

      CheckImportStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.poll_result.Payload.status"
            StringEquals = "COMPLETED"
            Next         = "WriteWatermark"
          },
          {
            Variable     = "$.poll_result.Payload.status"
            StringEquals = "FAILED"
            Next         = "NotifyFailure"
          }
        ]
        Default = "WaitForImport"
      }

      WriteWatermark = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ssm:putParameter"
        Parameters = {
          "Name.$" = "States.Format('/pipeline/${var.project_name}/${var.environment}/{}/bulk_complete_at', $.poll_result.Payload.registry)"
          "Value.$" = "$$.State.EnteredTime"
          Type      = "String"
          Overwrite = true
        }
        ResultPath = null
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "CheckResourceFailures"
      }

      # ── Per-resource failure check (first attempt) ──────────────────────────

      CheckResourceFailures = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.check_import_failures.arn
          Payload = {
            "job_id.$"      = "$.poll_result.Payload.job_id"
            "fhir_bucket.$" = "$.mapper_result.Payload.fhir_bucket"
            "fhir_key.$"    = "$.mapper_result.Payload.fhir_key"
            "registry.$"    = "$.poll_result.Payload.registry"
            retry_attempt   = 0
          }
        }
        ResultPath = "$.failure_result"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "ResourceFailureDecision"
      }

      ResourceFailureDecision = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.failure_result.Payload.has_failures"
            BooleanEquals = false
            Next          = "ImportComplete"
          },
          {
            And = [
              { Variable = "$.failure_result.Payload.has_failures", BooleanEquals = true },
              { Variable = "$.failure_result.Payload.retry_attempt", NumericEquals = 0 }
            ]
            Next = "RetryImportJob"
          }
        ]
        Default = "NotifyResourceFailures"
      }

      # ── Retry: re-import the same NDJSON (idempotent, different ClientToken) ─

      RetryImportJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.import_launcher.arn
          Payload = {
            "fhir_bucket.$"   = "$.failure_result.Payload.fhir_bucket"
            "fhir_key.$"      = "$.failure_result.Payload.fhir_key"
            "registry.$"      = "$.failure_result.Payload.registry"
            "retry_attempt.$" = "States.MathAdd($.failure_result.Payload.retry_attempt, 1)"
          }
        }
        ResultPath = "$.retry_import_result"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "WaitForRetry"
      }

      WaitForRetry = {
        Type    = "Wait"
        Seconds = 60
        Next    = "PollRetryStatus"
      }

      PollRetryStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.import_poller.arn
          "Payload.$"  = "$.retry_import_result.Payload"
        }
        ResultPath = "$.retry_poll_result"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "CheckRetryStatus"
      }

      CheckRetryStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.retry_poll_result.Payload.status"
            StringEquals = "COMPLETED"
            Next         = "CheckRetryFailures"
          },
          {
            Variable     = "$.retry_poll_result.Payload.status"
            StringEquals = "FAILED"
            Next         = "NotifyFailure"
          }
        ]
        Default = "WaitForRetry"
      }

      # ── Per-resource failure check (after retry) ────────────────────────────

      CheckRetryFailures = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.check_import_failures.arn
          Payload = {
            "job_id.$"      = "$.retry_poll_result.Payload.job_id"
            "fhir_bucket.$" = "$.failure_result.Payload.fhir_bucket"
            "fhir_key.$"    = "$.failure_result.Payload.fhir_key"
            "registry.$"    = "$.failure_result.Payload.registry"
            retry_attempt   = 1
          }
        }
        ResultPath = "$.retry_failure_result"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
          ResultPath  = "$.error"
        }]
        Next = "RetryFailureDecision"
      }

      RetryFailureDecision = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.retry_failure_result.Payload.has_failures"
            BooleanEquals = false
            Next          = "ImportComplete"
          }
        ]
        Default = "NotifyResourceFailures"
      }

      NotifyResourceFailures = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.import_failures.arn
          "Message.$" = "States.JsonToString($)"
        }
        Next = "ImportComplete"
      }

      ImportComplete = {
        Type = "Succeed"
      }

      NotifyFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.import_failures.arn
          "Message.$" = "States.JsonToString($)"
        }
        Next = "ImportFailed"
      }

      ImportFailed = {
        Type  = "Fail"
        Cause = "Import pipeline failed. Check SNS notification for details."
      }
    }
  })

  depends_on = [aws_cloudwatch_log_group.sfn_import]
}
