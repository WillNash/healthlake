variable "project_name" {
  type        = string
  description = "Short name for the project; used as a prefix on all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod). Used in resource names and tags."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "kms_deletion_window_days" {
  type        = number
  description = "Number of days to wait before deleting a KMS key after it is scheduled for deletion."
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "kms_deletion_window_days must be between 7 and 30."
  }
}

variable "cloudtrail_log_retention_days" {
  type        = number
  description = "Number of days to retain CloudTrail logs in CloudWatch Logs."
  default     = 90
}

variable "enable_guardduty" {
  type        = bool
  description = "Whether to create the GuardDuty detector. Set to false in dev to save cost. Never disable in prod."
  default     = true
}

variable "enable_macie" {
  type        = bool
  description = "Whether to enable Amazon Macie for automatic PHI discovery in S3. Set to false in dev to save cost."
  default     = true
}

variable "enable_securityhub" {
  type        = bool
  description = "Whether to enable AWS Security Hub and subscribe to FSBP and CIS 1.4 standards."
  default     = true
}

variable "waf_rate_limit" {
  type        = number
  description = "Maximum number of requests allowed per 5-minute window per IP before the WAF rate-based rule triggers."
  default     = 2000
}
