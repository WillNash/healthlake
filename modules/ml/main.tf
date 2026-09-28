# ---------------------------------------------------------------------------
# KMS key — dedicated to SageMaker EFS (Studio home directories)
# Kept separate from the main CMK so the key policy can be tightly scoped
# to the SageMaker service principal without broadening the main key policy.
# ---------------------------------------------------------------------------
resource "aws_kms_key" "sagemaker_efs" {
  count = var.enable_sagemaker ? 1 : 0

  description             = "SageMaker EFS encryption key for ${var.project_name} ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccountFullKMSAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "SageMakerEFSAccess"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-sagemaker-efs"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "sagemaker_efs" {
  count = var.enable_sagemaker ? 1 : 0

  name          = "alias/${var.project_name}/${var.environment}/sagemaker-efs"
  target_key_id = aws_kms_key.sagemaker_efs[0].key_id
}

# ---------------------------------------------------------------------------
# S3 bucket — SageMaker artefacts (model outputs, notebook outputs)
# Separate from the FHIR/analytics buckets to narrow the execution role policy.
# Object Lock in GOVERNANCE mode ensures HIPAA-required retention controls.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "sagemaker" {
  count = var.enable_sagemaker ? 1 : 0

  bucket = "${var.project_name}-${var.environment}-sagemaker"

  # Object Lock must be enabled at bucket creation time — cannot be added later.
  object_lock_enabled = true

  tags = {
    Name = "${var.project_name}-${var.environment}-sagemaker"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "sagemaker" {
  count = var.enable_sagemaker ? 1 : 0

  bucket = aws_s3_bucket.sagemaker[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_object_lock_configuration" "sagemaker" {
  count = var.enable_sagemaker ? 1 : 0

  bucket = aws_s3_bucket.sagemaker[0].id

  rule {
    default_retention {
      mode  = "GOVERNANCE"
      years = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  count = var.enable_sagemaker ? 1 : 0

  bucket = aws_s3_bucket.sagemaker[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "sagemaker" {
  count = var.enable_sagemaker ? 1 : 0

  bucket = aws_s3_bucket.sagemaker[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "sagemaker" {
  count = var.enable_sagemaker ? 1 : 0

  bucket = aws_s3_bucket.sagemaker[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyHTTP"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.sagemaker[0].arn,
          "${aws_s3_bucket.sagemaker[0].arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.sagemaker]
}

# ---------------------------------------------------------------------------
# SageMaker domain
# app_network_access_type = "VpcOnly" is mandatory for HIPAA: all traffic
# (including internet-bound calls from notebooks) traverses the VPC and must
# exit via VPC endpoints — no direct internet path is created.
#
# app_security_group_management = "Customer" enables customer-managed security
# groups. This is not required for plain VpcOnly mode without RStudio Server
# Pro, but it is included here to support a future RStudio addition without a
# destroy-and-recreate of the domain.
#
# sharing_settings.notebook_output_option = "Disabled" prevents notebook
# outputs from being shared outside the domain — a critical PHI exfiltration
# control.
# ---------------------------------------------------------------------------
resource "aws_sagemaker_domain" "main" {
  count = var.enable_sagemaker ? 1 : 0

  domain_name             = "${var.project_name}-${var.environment}"
  auth_mode               = "IAM"
  vpc_id                  = var.vpc_id
  subnet_ids              = var.private_subnet_ids
  app_network_access_type = "VpcOnly"
  kms_key_id              = aws_kms_key.sagemaker_efs[0].arn

  # NOTE: app_security_group_management = "Customer" is included for future
  # RStudio Server Pro compatibility. It is NOT required for a plain VpcOnly
  # domain without RStudio. Setting it now avoids a forced replacement later
  # when RStudio support is added.
  app_security_group_management = "Customer"

  default_user_settings {
    execution_role  = aws_iam_role.sagemaker_execution[0].arn
    security_groups = [var.sagemaker_security_group_id]

    sharing_settings {
      notebook_output_option = "Disabled"
      s3_kms_key_id          = var.kms_key_arn
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    aws_iam_role.sagemaker_execution,
    aws_kms_key.sagemaker_efs,
  ]
}

# ---------------------------------------------------------------------------
# SageMaker user profiles
# for_each over the sagemaker_users map. The guard condition
# (var.enable_sagemaker) is enforced by the fact that the domain resource
# (aws_sagemaker_domain.main[0]) only exists when enable_sagemaker = true;
# referencing its id here will produce a plan-time error if the domain is
# absent and users are specified, which is the desired guard behaviour.
#
# execution_role_arn can be left as an empty string to inherit the domain-
# level execution role — the conditional below handles the fallback.
# ---------------------------------------------------------------------------
resource "aws_sagemaker_user_profile" "users" {
  for_each = var.enable_sagemaker ? var.sagemaker_users : {}

  domain_id         = aws_sagemaker_domain.main[0].id
  user_profile_name = each.key

  user_settings {
    execution_role = each.value.execution_role_arn != "" ? each.value.execution_role_arn : aws_iam_role.sagemaker_execution[0].arn
  }

  tags = {
    Name = each.key
  }
}
