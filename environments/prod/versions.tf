terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.9"
    }
  }

  backend "s3" {
    # Values are supplied via backend.hcl (gitignored).
    # See environments/prod/backend.hcl.example.
    # Init with: terraform init -backend-config=backend.hcl
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "prod"
      ManagedBy   = "terraform"
      HIPAA       = "true"
    }
  }
}

provider "awscc" {
  region = var.aws_region
}
