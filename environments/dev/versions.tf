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
    # Fill in after bootstrap apply:
    # bucket         = "<tfstate_bucket_name from bootstrap output>"
    # key            = "dev/terraform.tfstate"
    # region         = "<aws_region>"
    # dynamodb_table = "<dynamodb_lock_table_name from bootstrap output>"
    # kms_key_id     = "<kms_key_arn from bootstrap output>"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
      HIPAA       = "true"
    }
  }
}

provider "awscc" {
  region = var.aws_region
}
