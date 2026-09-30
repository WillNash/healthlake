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

variable "redcap_projects" {
  type = map(object({
    url                 = string
    project_id          = string
    schedule_expression = optional(string, "cron(0 2 * * ? *)")
    page_size           = optional(number, 5000)
  }))
  description = "Map of registry name → REDCap project config. The key must match a registry name known to the mapper (either in _KNOWN or registry_map). Leave empty when using simulate mode only."
  default     = {}
}
