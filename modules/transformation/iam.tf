data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  healthlake_role_name = regex("([^/]+)$", var.healthlake_data_access_role_arn)[0]
}

# ── csv_to_fhir_mapper ────────────────────────────────────────────────────────

resource "aws_iam_role" "csv_to_fhir_mapper" {
  name = "${var.project_name}-${var.environment}-csv-to-fhir-mapper"

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

resource "aws_iam_role_policy" "csv_to_fhir_mapper" {
  name = "csv-to-fhir-mapper-inline"
  role = aws_iam_role.csv_to_fhir_mapper.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadLandingCSV"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${var.landing_bucket_arn}/*"]
      },
      {
        Sid      = "WriteFHIRStaging"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.fhir_staging.arn}/*"]
      },
      {
        Sid      = "KMS"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid      = "DLQ"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

# ── HealthLake data access role: fhir_staging read ────────────────────────────
# HealthLake reads NDJSON from fhir_staging during the import job.

resource "aws_iam_role_policy" "healthlake_fhir_staging_access" {
  name = "${var.project_name}-${var.environment}-hl-fhir-staging"
  role = local.healthlake_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadFHIRStaging"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.fhir_staging.arn, "${aws_s3_bucket.fhir_staging.arn}/*"]
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

# ── import_launcher ───────────────────────────────────────────────────────────

resource "aws_iam_role" "import_launcher" {
  name = "${var.project_name}-${var.environment}-import-launcher"

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

resource "aws_iam_role_policy" "import_launcher" {
  name = "import-launcher-inline"
  role = aws_iam_role.import_launcher.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StartImport"
        Effect   = "Allow"
        Action   = ["healthlake:StartFHIRImportJob"]
        Resource = [var.datastore_arn]
      },
      {
        Sid      = "WriteImportOutput"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::${var.import_output_bucket_name}/*"]
      },
      {
        Sid      = "KMS"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid      = "DLQ"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

# ── import_poller ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "import_poller" {
  name = "${var.project_name}-${var.environment}-import-poller"

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

resource "aws_iam_role_policy" "import_poller" {
  name = "import-poller-inline"
  role = aws_iam_role.import_poller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeImport"
        Effect   = "Allow"
        Action   = ["healthlake:DescribeFHIRImportJob"]
        Resource = [var.datastore_arn]
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid      = "DLQ"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

# ── check_import_failures ─────────────────────────────────────────────────────

resource "aws_iam_role" "check_import_failures" {
  name = "${var.project_name}-${var.environment}-check-import-failures"

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

resource "aws_iam_role_policy" "check_import_failures" {
  name = "check-import-failures-inline"
  role = aws_iam_role.check_import_failures.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadImportOutput"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.import_output_bucket_name}",
          "arn:aws:s3:::${var.import_output_bucket_name}/*",
        ]
      },
      {
        Sid      = "KMS"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid      = "DLQ"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

# ── Step Functions ────────────────────────────────────────────────────────────

resource "aws_iam_role" "sfn" {
  name = "${var.project_name}-${var.environment}-transformation-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SFNTrust"
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "sfn" {
  name = "sfn-inline"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeLambdas"
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.csv_to_fhir_mapper.arn,
          aws_lambda_function.import_launcher.arn,
          aws_lambda_function.import_poller.arn,
          aws_lambda_function.check_import_failures.arn,
        ]
      },
      {
        Sid      = "KMS"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [aws_sns_topic.import_failures.arn]
      },
      {
        Sid    = "WriteWatermark"
        Effect = "Allow"
        Action = ["ssm:PutParameter"]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/pipeline/${var.project_name}/${var.environment}/*"
        ]
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
          "logs:DescribeLogGroups",
        ]
        Resource = ["*"]
      }
    ]
  })
}

# ── EventBridge → SFN ─────────────────────────────────────────────────────────

resource "aws_iam_role" "events_to_sfn" {
  name = "${var.project_name}-${var.environment}-events-to-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EventsTrust"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "events_to_sfn" {
  name = "events-to-sfn-inline"
  role = aws_iam_role.events_to_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "StartSFN"
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [aws_sfn_state_machine.import_orchestrator.arn]
    }]
  })
}
