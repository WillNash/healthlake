variable "project_name" {
  type        = string
  description = "Short name for the project; used as a prefix on all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "kms_deletion_window_days" {
  type        = number
  description = "Days to wait before deleting a scheduled-for-deletion KMS key."
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "kms_deletion_window_days must be between 7 and 30."
  }
}

variable "cloudtrail_log_retention_days" {
  type        = number
  description = "Days to retain CloudTrail logs in CloudWatch Logs."
  default     = 90
}
