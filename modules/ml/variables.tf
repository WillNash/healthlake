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
  description = "ARN of the main CMK (from the security module) used for S3 and SageMaker output encryption."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the SageMaker domain. VpcOnly mode requires this."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the SageMaker domain. Must span at least 2 AZs."
}

variable "sagemaker_security_group_id" {
  type        = string
  description = "Security group ID applied to SageMaker apps and the domain (from the networking module)."
}

variable "analytics_bucket_arn" {
  type        = string
  description = "ARN of the analytics S3 bucket (Iceberg Parquet tables) the SageMaker execution role reads for ML training."
}

variable "athena_workgroup_name" {
  type        = string
  description = "Name of the Athena workgroup the SageMaker execution role is permitted to query."
}

variable "glue_database_name" {
  type        = string
  description = "Name of the Glue catalog database the SageMaker execution role can read table metadata from."
}

variable "enable_sagemaker" {
  type        = bool
  description = "Master toggle. Set false in dev to avoid SageMaker costs. All resources except user profiles are gated on this flag."
  default     = false
}

variable "sagemaker_users" {
  type = map(object({
    execution_role_arn = string
  }))
  description = "Map of SageMaker user profiles to create, keyed by user_profile_name. Set execution_role_arn to an empty string to fall back to the domain-level execution role."
  default     = {}
}
