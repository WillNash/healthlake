output "kms_key_arn" {
  description = "ARN of the clinical data CMK. Pass to all other modules that require KMS encryption."
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

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector. Empty string when enable_guardduty is false."
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : ""
}

output "waf_web_acl_arn" {
  description = "ARN of the regional WAF Web ACL. Associate with ALB or API Gateway resources."
  value       = aws_wafv2_web_acl.main.arn
}

output "lakeformation_service_role_arn" {
  description = "ARN of the IAM role used by Lake Formation for S3 path registration. Pass to the analytics module."
  value       = aws_iam_role.lakeformation_service.arn
}
