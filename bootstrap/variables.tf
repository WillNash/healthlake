variable "aws_region" {
  type        = string
  description = "AWS region to deploy bootstrap resources into. Must be one of the eight HealthLake-eligible regions."

  validation {
    condition = contains([
      "us-east-1",
      "us-east-2",
      "us-west-2",
      "ap-south-1",
      "ap-southeast-2",
      "ca-central-1",
      "eu-west-1",
      "eu-west-2",
    ], var.aws_region)
    error_message = "aws_region must be one of the eight HealthLake-eligible regions: us-east-1, us-east-2, us-west-2, ap-south-1, ap-southeast-2, ca-central-1, eu-west-1, eu-west-2."
  }
}

variable "project_name" {
  type        = string
  description = "Short name for the project; used as a prefix on all bootstrap resource names."

  validation {
    condition     = can(regex("^[a-z0-9-]{1,24}$", var.project_name))
    error_message = "project_name must be 1–24 lowercase alphanumeric characters or hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Used in resource names and tags."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "allowed_deployer_arns" {
  type        = list(string)
  description = "IAM principal ARNs (users or roles) that are granted full KMS key access in addition to the root account. Typically the CI/CD role ARN."
  default     = []
}
