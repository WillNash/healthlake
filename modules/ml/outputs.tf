output "sagemaker_domain_id" {
  description = "ID of the SageMaker domain, or an empty string when enable_sagemaker = false."
  value       = try(aws_sagemaker_domain.main[0].id, "")
}

output "sagemaker_domain_arn" {
  description = "ARN of the SageMaker domain, or an empty string when enable_sagemaker = false."
  value       = try(aws_sagemaker_domain.main[0].arn, "")
}

output "sagemaker_execution_role_arn" {
  description = "ARN of the SageMaker execution IAM role. Passed to the analytics module for Lake Formation grants."
  value       = try(aws_iam_role.sagemaker_execution[0].arn, "")
}

output "sagemaker_bucket_name" {
  description = "Name of the SageMaker S3 bucket, or an empty string when enable_sagemaker = false."
  value       = try(aws_s3_bucket.sagemaker[0].bucket, "")
}

output "sagemaker_bucket_arn" {
  description = "ARN of the SageMaker S3 bucket, or an empty string when enable_sagemaker = false."
  value       = try(aws_s3_bucket.sagemaker[0].arn, "")
}

output "sagemaker_efs_kms_key_arn" {
  description = "ARN of the dedicated SageMaker EFS KMS key, or an empty string when enable_sagemaker = false."
  value       = try(aws_kms_key.sagemaker_efs[0].arn, "")
}
