variable "project_name" {
  type        = string
  description = "Name of the project; used as a prefix for all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the CMK from the security module used for S3, SQS, Lambda, and Secrets Manager encryption."
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC in which the Lambda function will run."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the Lambda VPC configuration."
}

variable "lambda_security_group_id" {
  type        = string
  description = "ID of the security group to attach to the Lambda function."
}

variable "redcap_url" {
  type        = string
  description = "Base URL of the REDCap instance (e.g. https://redcap.example.com). Must not include a trailing slash or /api/index.php path."
}

variable "redcap_project_id" {
  type        = string
  description = "REDCap project identifier; used in the S3 object key to distinguish exports from different projects."
}

variable "export_schedule_expression" {
  type        = string
  description = "EventBridge Scheduler cron or rate expression for the nightly REDCap export."
  default     = "cron(0 2 * * ? *)"
}

variable "redcap_page_size" {
  type        = number
  description = "Number of REDCap records to export per paginated request."
  default     = 5000
}
