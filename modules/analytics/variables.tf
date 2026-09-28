variable "project_name" {
  type        = string
  description = "Project name prefix applied to all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev or prod)."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS CMK used to encrypt all resources in this module."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID in which Lambda functions are deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for Lambda VPC attachment."
}

variable "lambda_security_group_id" {
  type        = string
  description = "Security group ID applied to all VPC-attached Lambda functions."
}

variable "datastore_id" {
  type        = string
  description = "HealthLake FHIR R4 datastore ID."
}

variable "fhir_export_bucket_name" {
  type        = string
  description = "Name of the S3 bucket that receives HealthLake bulk FHIR export output."
}

variable "fhir_export_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket that receives HealthLake bulk FHIR export output."
}

variable "healthlake_export_role_arn" {
  type        = string
  description = "ARN of the IAM role that HealthLake assumes when writing bulk FHIR export output."
}

variable "fhir_resource_tables" {
  type        = list(string)
  description = "List of FHIR resource type names for which Iceberg tables are created."
  default     = ["patient", "observation", "condition", "procedure", "medication_request", "encounter", "diagnostic_report"]
}

variable "glue_worker_count" {
  type        = number
  description = "Number of Glue workers for the fhir_to_iceberg ETL job."
  default     = 2
}

variable "quicksight_service_role_arn" {
  type        = string
  description = "ARN of the QuickSight service IAM role. Lake Formation SELECT/DESCRIBE is granted to this role. Leave empty to skip the grant."
  default     = ""
}

variable "sagemaker_execution_role_arn" {
  type        = string
  description = "ARN of the SageMaker execution IAM role. Lake Formation SELECT/DESCRIBE is granted to this role. Leave empty to skip the grant."
  default     = ""
}

variable "additional_analyst_role_arns" {
  type        = list(string)
  description = "Additional IAM role ARNs granted Lake Formation SELECT/DESCRIBE on all Iceberg tables."
  default     = []
}
