data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name
}

# ---------------------------------------------------------------------------
# KMS key — clinical data CMK shared across all pipeline modules
# ---------------------------------------------------------------------------

resource "aws_kms_key" "main" {
  description             = "Clinical data encryption CMK for ${local.name_prefix}"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "HealthLakeAccess"
        Effect = "Allow"
        Principal = {
          Service = "healthlake.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:*"
          }
        }
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
      {
        Sid    = "ComprehendMedicalAccess"
        Effect = "Allow"
        Principal = {
          Service = "comprehendmedical.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
      {
        Sid    = "StepFunctionsAccess"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
      {
        Sid    = "SchedulerAccess"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = "*"
      },
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-clinical-cmk"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}/${var.environment}/main"
  target_key_id = aws_kms_key.main.key_id
}

# ---------------------------------------------------------------------------
# S3 bucket — CloudTrail log storage
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${local.name_prefix}-cloudtrail-${local.account_id}"

  # object_lock_enabled must be set at bucket creation time; the separate
  # aws_s3_bucket_object_lock_configuration resource configures the default retention.
  object_lock_enabled = true

  tags = {
    Name        = "${local.name_prefix}-cloudtrail"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 365
    }
  }

  depends_on = [aws_s3_bucket_versioning.cloudtrail]
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyNonKMSPutObject"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid    = "CloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid    = "CloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/cloudtrail/AWSLogs/${local.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"     = "bucket-owner-full-control"
            "aws:SourceAccount" = local.account_id
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail]
}

# ---------------------------------------------------------------------------
# CloudWatch Log Group — CloudTrail logs
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = var.cloudtrail_log_retention_days
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name        = "${local.name_prefix}-cloudtrail-logs"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }
}

# ---------------------------------------------------------------------------
# CloudTrail
# ---------------------------------------------------------------------------

resource "aws_cloudtrail" "main" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = "cloudtrail"
  kms_key_id                    = aws_kms_key.main.arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*"]
    }
  }

  tags = {
    Name        = "${local.name_prefix}-trail"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ---------------------------------------------------------------------------
# GuardDuty
# ---------------------------------------------------------------------------

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = {
    Name        = "${local.name_prefix}-guardduty"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }
}

# ---------------------------------------------------------------------------
# Security Hub
# ---------------------------------------------------------------------------

resource "aws_securityhub_account" "main" {
  count = var.enable_securityhub ? 1 : 0
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  for_each = var.enable_securityhub ? toset([
    "arn:aws:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0",
    "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0",
  ]) : toset([])

  standards_arn = each.value

  depends_on = [aws_securityhub_account.main]
}

# ---------------------------------------------------------------------------
# WAF v2 Web ACL — REGIONAL scope (attach to ALB/API Gateway in other modules)
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "main" {
  name  = "${local.name_prefix}-web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 30

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${local.name_prefix}-web-acl"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }
}

# ---------------------------------------------------------------------------
# Macie
# ---------------------------------------------------------------------------

resource "aws_macie2_account" "main" {
  count = var.enable_macie ? 1 : 0

  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

# ---------------------------------------------------------------------------
# Lake Formation service role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lakeformation_service" {
  name = "${local.name_prefix}-lakeformation-service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LakeFormationTrust"
        Effect = "Allow"
        Principal = {
          Service = "lakeformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-lakeformation-service"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }
}

resource "aws_iam_role_policy_attachment" "lakeformation_admin" {
  role       = aws_iam_role.lakeformation_service.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLakeFormationDataAdmin"
}

# ---------------------------------------------------------------------------
# CloudTrail IAM role — allows CloudTrail to write to CloudWatch Logs
# ---------------------------------------------------------------------------

resource "aws_iam_role" "cloudtrail" {
  name = "${local.name_prefix}-cloudtrail"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudTrailTrust"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-cloudtrail"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
  }
}

resource "aws_iam_role_policy" "cloudtrail" {
  name = "${local.name_prefix}-cloudtrail-logs"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}
