variable "project_name" {
  type        = string
  description = "Project name prefix applied to all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev or prod."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the main CMK (from the security module) used for KMS encryption."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID in which the QuickSight security group is created."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the QuickSight VPC connection."
}

variable "vpc_endpoint_security_group_id" {
  type        = string
  description = "Security group ID of the VPC endpoints SG; QuickSight egress is scoped to this target."
}

variable "analytics_bucket_arn" {
  type        = string
  description = "ARN of the analytics S3 bucket (Iceberg Parquet tables) from the analytics module."
}

variable "athena_results_bucket_arn" {
  type        = string
  description = "ARN of the Athena results S3 bucket from the analytics module."
}

variable "athena_workgroup_name" {
  type        = string
  description = "Name of the Athena workgroup (from the analytics module)."
}

variable "glue_database_name" {
  type        = string
  description = "Name of the Glue catalog database (from the analytics module)."
}

variable "create_subscription" {
  type        = bool
  description = "Set to true on first apply in a new account to create the QuickSight Enterprise subscription. Set false once the subscription exists."
  default     = false
}

variable "enable_vpc_connection" {
  type        = bool
  description = "Create the QuickSight VPC connection resource. Set false in dev environments without private connectivity."
  default     = true
}

variable "notification_email" {
  type        = string
  description = "Email address for QuickSight account subscription notifications. Required when create_subscription = true."
  default     = ""
}

variable "admin_quicksight_user" {
  type        = string
  description = "QuickSight admin username (namespace/username format) granted permissions on the Athena data source."
  default     = ""
}
