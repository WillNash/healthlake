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

variable "redcap_projects" {
  type = map(object({
    url                 = string
    project_id          = string
    schedule_expression = optional(string, "cron(0 2 * * ? *)")
    page_size           = optional(number, 5000)
  }))
  description = "Map of registry name → REDCap project config. Leave empty when using simulate mode only."
  default     = {}
}

variable "registry_map" {
  type        = map(string)
  description = "Map of REDCap project IDs to registry names. Populate once live project IDs are known (e.g. {\"1001\" = \"ovarian_cancer\"})."
  default     = {}
}
