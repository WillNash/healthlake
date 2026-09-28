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
  description = "Whether to provision NAT Gateways. True in prod for outbound traffic that cannot route via VPC endpoints."
  default     = true
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

variable "registry_map" {
  type        = map(string)
  description = "Map of REDCap project IDs to registry names. Populate once live project IDs are known (e.g. {\"1001\" = \"ovarian_cancer\"})."
  default     = {}
}
