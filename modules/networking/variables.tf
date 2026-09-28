variable "project_name" {
  type        = string
  description = "Short name for the project; used as a prefix on all resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod). Used in resource names and tags."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region in which VPC endpoints and other region-scoped resources are created."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_cidrs" {
  type        = map(string)
  description = "Map of Availability Zone suffix to CIDR block for private subnets. Example: { a = \"10.0.1.0/24\", b = \"10.0.2.0/24\", c = \"10.0.3.0/24\" }."
}

variable "public_subnet_cidrs" {
  type        = map(string)
  description = "Map of Availability Zone suffix to CIDR block for public subnets. Used only for NAT Gateways — no compute runs here. Example: { a = \"10.0.101.0/24\", b = \"10.0.102.0/24\", c = \"10.0.103.0/24\" }."
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to provision NAT Gateways (one per public subnet). Set to false in dev when VPC endpoints cover all required outbound traffic."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the clinical data CMK from the security module. Used to encrypt the VPC Flow Logs CloudWatch log group."
}
