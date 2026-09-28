# ── Lambda archive files ──────────────────────────────────────────────────────

data "archive_file" "export_chain_trigger" {
  type        = "zip"
  source_file = "${path.module}/lambda/export_chain_trigger/handler.py"
  output_path = "${path.module}/lambda/export_chain_trigger/handler.zip"
}

data "archive_file" "export_launcher" {
  type        = "zip"
  source_file = "${path.module}/lambda/export_launcher/handler.py"
  output_path = "${path.module}/lambda/export_launcher/handler.zip"
}

data "archive_file" "export_poller" {
  type        = "zip"
  source_file = "${path.module}/lambda/export_poller/handler.py"
  output_path = "${path.module}/lambda/export_poller/handler.zip"
}

data "archive_file" "glue_trigger" {
  type        = "zip"
  source_file = "${path.module}/lambda/glue_trigger/handler.py"
  output_path = "${path.module}/lambda/glue_trigger/handler.zip"
}

# ── SNS: analytics failures ───────────────────────────────────────────────────

resource "aws_sns_topic" "analytics_failures" {
  name              = "${var.project_name}-${var.environment}-analytics-failures"
  kms_master_key_id = var.kms_key_arn
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "export_chain_trigger" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-export-chain-trigger"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "export_launcher" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-export-launcher"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "export_poller" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-export-poller"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "glue_trigger" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-glue-trigger"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "export_etl_sfn" {
  name              = "/aws/states/${var.project_name}-${var.environment}-export-etl-orchestrator"
  kms_key_id        = var.kms_key_arn
  retention_in_days = 90
}

# ── IAM: export_chain_trigger Lambda ─────────────────────────────────────────

resource "aws_iam_role" "export_chain_trigger" {
  name = "${var.project_name}-${var.environment}-export-chain-trigger"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaTrust"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "export_chain_trigger" {
  name = "export-chain-trigger-inline"
  role = aws_iam_role.export_chain_trigger.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartExportSFN"
        Effect = "Allow"
        Action = ["states:StartExecution"]
        Resource = [aws_sfn_state_machine.export_etl_orchestrator.arn]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "export_chain_trigger_vpc" {
  role       = aws_iam_role.export_chain_trigger.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── IAM: export_launcher Lambda ───────────────────────────────────────────────

resource "aws_iam_role" "export_launcher" {
  name = "${var.project_name}-${var.environment}-export-launcher"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaTrust"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "export_launcher" {
  name = "export-launcher-inline"
  role = aws_iam_role.export_launcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartExport"
        Effect = "Allow"
        Action = ["healthlake:StartFHIRExportJob"]
        Resource = ["arn:aws:healthlake:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:datastore/fhir/${var.datastore_id}"]
      },
      {
        Sid    = "PassExportRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [var.healthlake_export_role_arn]
      },
      {
        Sid    = "WriteFHIRExport"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:ListBucket"]
        Resource = [
          var.fhir_export_bucket_arn,
          "${var.fhir_export_bucket_arn}/*"
        ]
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "export_launcher_vpc" {
  role       = aws_iam_role.export_launcher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── IAM: export_poller Lambda ─────────────────────────────────────────────────

resource "aws_iam_role" "export_poller" {
  name = "${var.project_name}-${var.environment}-export-poller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaTrust"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "export_poller" {
  name = "export-poller-inline"
  role = aws_iam_role.export_poller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeExport"
        Effect = "Allow"
        Action = ["healthlake:DescribeFHIRExportJob"]
        Resource = ["arn:aws:healthlake:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:datastore/fhir/${var.datastore_id}"]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "export_poller_vpc" {
  role       = aws_iam_role.export_poller.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── IAM: glue_trigger Lambda ──────────────────────────────────────────────────

resource "aws_iam_role" "glue_trigger_lambda" {
  name = "${var.project_name}-${var.environment}-glue-trigger-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "LambdaTrust"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue_trigger_lambda" {
  name = "glue-trigger-inline"
  role = aws_iam_role.glue_trigger_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StartGlueJob"
        Effect = "Allow"
        Action = ["glue:StartJobRun"]
        Resource = ["arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/${aws_glue_job.fhir_to_iceberg.name}"]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_trigger_lambda_vpc" {
  role       = aws_iam_role.glue_trigger_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── IAM: analytics Step Functions ────────────────────────────────────────────

resource "aws_iam_role" "analytics_sfn" {
  name = "${var.project_name}-${var.environment}-analytics-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SFNTrust"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "analytics_sfn" {
  name = "analytics-sfn-inline"
  role = aws_iam_role.analytics_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambdas"
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.export_launcher.arn,
          aws_lambda_function.export_poller.arn,
          aws_lambda_function.glue_trigger.arn
        ]
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = [aws_sns_topic.analytics_failures.arn]
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogDelivery",
          "logs:PutLogEvents",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# ── Lambda: export_chain_trigger ──────────────────────────────────────────────
# This Lambda is invoked by the transformation module's Step Functions state
# machine COMPLETED branch. It starts the analytics export Step Functions.
# Its ARN is output as export_chain_trigger_lambda_arn for the transformation
# module to consume.

resource "aws_lambda_function" "export_chain_trigger" {
  function_name = "${var.project_name}-${var.environment}-export-chain-trigger"
  role          = aws_iam_role.export_chain_trigger.arn
  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.export_chain_trigger.output_path
  kms_key_arn   = var.kms_key_arn

  environment {
    variables = {
      EXPORT_ETL_SFN_ARN = aws_sfn_state_machine.export_etl_orchestrator.arn
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [aws_cloudwatch_log_group.export_chain_trigger]
}

# ── Lambda: export_launcher ───────────────────────────────────────────────────

resource "aws_lambda_function" "export_launcher" {
  function_name = "${var.project_name}-${var.environment}-export-launcher"
  role          = aws_iam_role.export_launcher.arn
  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.export_launcher.output_path
  timeout       = 60
  kms_key_arn   = var.kms_key_arn

  environment {
    variables = {
      DATASTORE_ID              = var.datastore_id
      FHIR_EXPORT_BUCKET        = var.fhir_export_bucket_name
      KMS_KEY_ARN               = var.kms_key_arn
      HEALTHLAKE_EXPORT_ROLE_ARN = var.healthlake_export_role_arn
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [aws_cloudwatch_log_group.export_launcher]
}

# ── Lambda: export_poller ─────────────────────────────────────────────────────

resource "aws_lambda_function" "export_poller" {
  function_name = "${var.project_name}-${var.environment}-export-poller"
  role          = aws_iam_role.export_poller.arn
  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.export_poller.output_path
  timeout       = 30
  kms_key_arn   = var.kms_key_arn

  environment {
    variables = {
      DATASTORE_ID = var.datastore_id
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [aws_cloudwatch_log_group.export_poller]
}

# ── Lambda: glue_trigger ──────────────────────────────────────────────────────

resource "aws_lambda_function" "glue_trigger" {
  function_name = "${var.project_name}-${var.environment}-glue-trigger"
  role          = aws_iam_role.glue_trigger_lambda.arn
  runtime       = "python3.12"
  architectures = ["arm64"]
  handler       = "handler.lambda_handler"
  filename      = data.archive_file.glue_trigger.output_path
  timeout       = 60
  kms_key_arn   = var.kms_key_arn

  environment {
    variables = {
      GLUE_JOB_NAME      = aws_glue_job.fhir_to_iceberg.name
      FHIR_EXPORT_BUCKET = var.fhir_export_bucket_name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  depends_on = [aws_cloudwatch_log_group.glue_trigger]
}

# ── Step Functions: export ETL orchestrator ───────────────────────────────────

resource "aws_sfn_state_machine" "export_etl_orchestrator" {
  name     = "${var.project_name}-${var.environment}-export-etl-orchestrator"
  type     = "STANDARD"
  role_arn = aws_iam_role.analytics_sfn.arn

  encryption_configuration {
    kms_key_id                        = var.kms_key_arn
    type                              = "CUSTOMER_MANAGED_KMS_KEY"
    kms_data_key_reuse_period_seconds = 300
  }

  logging_configuration {
    level                  = "ALL"
    include_execution_data = true
    log_destination        = "${aws_cloudwatch_log_group.export_etl_sfn.arn}:*"
  }

  definition = jsonencode({
    Comment = "Orchestrates HealthLake FHIR bulk export followed by Glue ETL to Iceberg."
    StartAt = "LaunchExport"
    States = {
      LaunchExport = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.export_launcher.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.export_result"
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyExportFailure"
          ResultPath  = "$.error"
        }]
        Next = "WaitForExport"
      }

      WaitForExport = {
        Type    = "Wait"
        Seconds = 120
        Next    = "PollExportStatus"
      }

      PollExportStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.export_poller.arn
          "Payload.$"  = "$.export_result.Payload"
        }
        ResultPath = "$.poll_result"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyExportFailure"
          ResultPath  = "$.error"
        }]
        Next = "CheckExportStatus"
      }

      CheckExportStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.poll_result.Payload.status"
            StringEquals = "COMPLETED"
            Next         = "TriggerGlueETL"
          },
          {
            Variable     = "$.poll_result.Payload.status"
            StringEquals = "FAILED"
            Next         = "NotifyExportFailure"
          }
        ]
        Default = "WaitForExport"
      }

      TriggerGlueETL = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.glue_trigger.arn
          "Payload.$"  = "$.poll_result.Payload"
        }
        ResultPath = "$.glue_result"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyExportFailure"
          ResultPath  = "$.error"
        }]
        Next = "ExportComplete"
      }

      ExportComplete = {
        Type = "Succeed"
      }

      NotifyExportFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn    = aws_sns_topic.analytics_failures.arn
          "Message.$" = "States.JsonToString($)"
        }
        Next = "ExportFailed"
      }

      ExportFailed = {
        Type  = "Fail"
        Cause = "Analytics export ETL pipeline failed. Check SNS notification for details."
      }
    }
  })

  depends_on = [aws_cloudwatch_log_group.export_etl_sfn]
}
