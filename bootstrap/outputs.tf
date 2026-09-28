output "tfstate_bucket_name" {
  description = "Name of the S3 bucket used to store Terraform state. Paste into each environment's backend block."
  value       = aws_s3_bucket.tfstate.id
}

output "tfstate_bucket_arn" {
  description = "ARN of the Terraform state S3 bucket."
  value       = aws_s3_bucket.tfstate.arn
}

output "dynamodb_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking. Paste into each environment's backend block."
  value       = aws_dynamodb_table.tflock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key that encrypts state bucket objects and the DynamoDB lock table. Paste into each environment's backend kms_key_id argument."
  value       = aws_kms_key.tfstate.arn
}
