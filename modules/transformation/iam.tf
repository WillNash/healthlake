data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── import_launcher Lambda role ──────────────────────────────────────────────

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
        Sid    = "StartImport"
        Effect = "Allow"
        Action = ["healthlake:StartFHIRImportJob"]
        Resource = [var.datastore_arn]
      },
      {
        Sid    = "WriteImportOutput"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = ["arn:aws:s3:::${var.import_output_bucket_name}/*"]
      },
      {
        Sid    = "KMSImportOutput"
        Effect = "Allow"
        Action = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid    = "DLQ"
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "import_launcher_vpc" {
  role       = aws_iam_role.import_launcher.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── import_poller Lambda role ─────────────────────────────────────────────────

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
        Sid    = "DescribeImport"
        Effect = "Allow"
        Action = ["healthlake:DescribeFHIRImportJob"]
        Resource = [var.datastore_arn]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid    = "DLQ"
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "import_poller_vpc" {
  role       = aws_iam_role.import_poller.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── comprehend_processor Lambda role ─────────────────────────────────────────

resource "aws_iam_role" "comprehend_processor" {
  name = "${var.project_name}-${var.environment}-comprehend-processor"

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

resource "aws_iam_role_policy" "comprehend_processor" {
  name = "comprehend-processor-inline"
  role = aws_iam_role.comprehend_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ComprehendMedical"
        Effect = "Allow"
        Action = [
          "comprehendmedical:DetectEntitiesV2",
          "comprehendmedical:InferICD10CM",
          "comprehendmedical:InferRxNorm",
          "comprehendmedical:InferSNOMEDCT"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "HealthLakeWrite"
        Effect = "Allow"
        Action = ["healthlake:CreateResource"]
        Resource = [var.datastore_arn]
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Sid    = "DLQ"
        Effect = "Allow"
        Action = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.lambda_dlq.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "comprehend_processor_vpc" {
  role       = aws_iam_role.comprehend_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Step Functions role ───────────────────────────────────────────────────────

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
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
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
          aws_lambda_function.import_launcher.arn,
          aws_lambda_function.import_poller.arn,
          aws_lambda_function.comprehend_processor.arn,
          var.analytics_export_trigger_lambda_arn
        ]
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = [aws_sns_topic.import_failures.arn]
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

# ── EventBridge → SFN role ────────────────────────────────────────────────────

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
      Sid    = "StartSFN"
      Effect = "Allow"
      Action = ["states:StartExecution"]
      Resource = [aws_sfn_state_machine.import_orchestrator.arn]
    }]
  })
}
