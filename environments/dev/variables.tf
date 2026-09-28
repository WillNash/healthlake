variable "aws_region" {
  type        = string
  description = "AWS region for all resources. Must be one of the regions where Amazon HealthLake is available."

  validation {
    condition = contains([
      "us-east-1",
      "us-east-2",
      "us-west-2",
      "ap-southeast-2",
      "ap-northeast-1",
      "eu-west-1",
      "eu-west-2",
      "eu-central-1",
    ], var.aws_region)
    error_message = "aws_region must be one of the 8 regions where Amazon HealthLake is available."
  }
}

variable "project_name" {
  type        = string
  description = "Short name for the project; used as a prefix on all resource names."
  default     = "clinical-registry"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  type        = map(string)
  description = "Map of Availability Zone suffix to CIDR block for private subnets."
  default = {
    a = "10.0.1.0/24"
    b = "10.0.2.0/24"
  }
}

variable "public_subnet_cidrs" {
  type        = map(string)
  description = "Map of Availability Zone suffix to CIDR block for public subnets. Used for NAT Gateways only."
  default = {
    a = "10.0.101.0/24"
    b = "10.0.102.0/24"
  }
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to provision NAT Gateways. False in dev — VPC endpoints cover all required AWS API calls."
  default     = false
}

variable "redcap_url" {
  type        = string
  description = "Base URL of the REDCap instance (e.g. https://redcap.example.com). Must not include a trailing slash."
  sensitive   = true
}

variable "redcap_project_id" {
  type        = string
  description = "REDCap project identifier; used in S3 object key paths to distinguish exports from different projects."
  sensitive   = true
}

variable "export_schedule_expression" {
  type        = string
  description = "EventBridge Scheduler cron or rate expression for the nightly REDCap export."
  default     = "cron(0 2 * * ? *)"
}

variable "dta_profile_id" {
  type        = string
  description = "Data Transformation Agent CSV profile ID. Leave empty string until the profile has been created out-of-band."
  default     = ""
  sensitive   = true
}

variable "comprehend_free_text_fields" {
  type        = list(string)
  description = "List of REDCap field names whose values are processed by Comprehend Medical. Empty list disables processing."
  default     = []
}

variable "enable_guardduty" {
  type        = bool
  description = "Whether to create the GuardDuty detector."
  default     = true
}

variable "enable_macie" {
  type        = bool
  description = "Whether to enable Amazon Macie for automatic PHI discovery."
  default     = true
}

variable "enable_securityhub" {
  type        = bool
  description = "Whether to enable AWS Security Hub."
  default     = true
}

variable "glue_worker_count" {
  type        = number
  description = "Number of Glue workers for the fhir_to_iceberg ETL job."
  default     = 2
}

variable "additional_analyst_role_arns" {
  type        = list(string)
  description = "Additional IAM role ARNs granted Lake Formation SELECT/DESCRIBE on all Iceberg tables."
  default     = []
}

variable "create_quicksight_subscription" {
  type        = bool
  description = "Set to true on first apply in a new account to create the QuickSight Enterprise subscription."
  default     = false
}

variable "notification_email" {
  type        = string
  description = "Email address for QuickSight account subscription notifications. Required when create_quicksight_subscription = true."
  default     = ""
}

variable "enable_sagemaker" {
  type        = bool
  description = "Master toggle for all SageMaker resources. False in dev to avoid SageMaker costs."
  default     = false
}

variable "sagemaker_users" {
  type = map(object({
    execution_role_arn = string
  }))
  description = "Map of SageMaker user profiles to create, keyed by user_profile_name."
  default     = {}
}
