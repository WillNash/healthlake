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
  description = "ARN of the KMS CMK used to encrypt Lambda environment variables, SQS, SNS, Step Functions, and CloudWatch log groups."
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

variable "datastore_endpoint" {
  type        = string
  description = "HealthLake FHIR R4 datastore HTTPS endpoint."
}

variable "datastore_arn" {
  type        = string
  description = "ARN of the HealthLake FHIR R4 datastore."
}

variable "landing_bucket_name" {
  type        = string
  description = "Name of the S3 landing bucket that receives REDCap CSV exports."
}

variable "landing_bucket_arn" {
  type        = string
  description = "ARN of the S3 landing bucket."
}

variable "import_output_bucket_name" {
  type        = string
  description = "Name of the S3 bucket that receives HealthLake import job output and provenance."
}

variable "healthlake_data_access_role_arn" {
  type        = string
  description = "ARN of the IAM role that HealthLake assumes when reading input data and writing import output."
}

variable "registry_map" {
  type        = map(string)
  description = "Map of REDCap project IDs to registry names (e.g. {\"1001\" = \"ovarian_cancer\"}). Used by csv_to_fhir_mapper to dispatch to the correct mapping module. Leave empty when using simulation paths."
  default     = {}
}

variable "comprehend_free_text_fields" {
  type        = list(string)
  description = "List of REDCap field names whose values are processed by Comprehend Medical. Empty list disables Comprehend processing."
  default     = []
}

variable "analytics_export_trigger_lambda_arn" {
  type        = string
  description = "ARN of the analytics module export_chain_trigger Lambda. The transformation Step Functions state machine invokes this Lambda in its COMPLETED branch."
}
