variable "project_name" {
  type        = string
  description = "Name of the project; used as a prefix for all resource names and as the HealthLake datastore name stem."
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "healthlake_enabled" {
  type        = bool
  description = "When false the HealthLake datastore is destroyed (and not recreated) to stop the hourly charge. S3 buckets and KMS key are unaffected."
  default     = true
}

variable "landing_bucket_arn" {
  type        = string
  description = "ARN of the S3 landing bucket from the ingestion module. Granted to the HealthLake data access role for import jobs."
}
