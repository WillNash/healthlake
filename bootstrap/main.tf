data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    HIPAA       = "true"
    Module      = "bootstrap"
  }
}

# ---------------------------------------------------------------------------
# KMS key — encrypts the Terraform state bucket and DynamoDB lock table
# ---------------------------------------------------------------------------

resource "aws_kms_key" "tfstate" {
  description             = "Terraform state encryption key for ${local.name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "RootAccountFullAccess"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action   = "kms:*"
          Resource = "*"
        }
      ],
      length(var.allowed_deployer_arns) > 0 ? [
        {
          Sid    = "DeployerAccess"
          Effect = "Allow"
          Principal = {
            AWS = var.allowed_deployer_arns
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
            "kms:CreateGrant",
            "kms:ListGrants",
            "kms:RevokeGrant",
          ]
          Resource = "*"
        }
      ] : []
    )
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tfstate-kms"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${var.project_name}/${var.environment}/tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

# ---------------------------------------------------------------------------
# S3 bucket — stores Terraform state files
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.name_prefix}-tfstate-${data.aws_caller_identity.current.account_id}"

  # object_lock_enabled must be set at bucket creation time; the separate
  # aws_s3_bucket_object_lock_configuration resource configures the default retention.
  object_lock_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tfstate"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_object_lock_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*",
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
        Resource  = "${aws_s3_bucket.tfstate.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# ---------------------------------------------------------------------------
# DynamoDB table — Terraform state locking
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "tflock" {
  name         = "${local.name_prefix}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tflock"
  })

  lifecycle {
    prevent_destroy = true
  }
}
