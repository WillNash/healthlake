output "kms_key_arn" {
  description = "ARN of the clinical data CMK. Pass to all modules that require KMS encryption."
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "Key ID (short form) of the clinical data CMK."
  value       = aws_kms_key.main.key_id
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket storing CloudTrail logs."
  value       = aws_s3_bucket.cloudtrail.id
}
