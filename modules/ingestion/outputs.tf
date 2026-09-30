output "landing_bucket_name" {
  description = "Name of the S3 landing bucket that receives REDCap CSV exports."
  value       = aws_s3_bucket.landing.id
}

output "landing_bucket_arn" {
  description = "ARN of the S3 landing bucket."
  value       = aws_s3_bucket.landing.arn
}

output "redcap_token_secret_arns" {
  description = "Map of registry name → Secrets Manager secret ARN for each REDCap project API token."
  value       = { for k, s in aws_secretsmanager_secret.redcap_token : k => s.arn }
}

output "redcap_exporter_lambda_arns" {
  description = "Map of registry name → ARN of the REDCap exporter Lambda for each project."
  value       = { for k, fn in aws_lambda_function.redcap_exporter : k => fn.arn }
}

output "scheduler_schedule_group_name" {
  description = "Name of the EventBridge Scheduler schedule group."
  value       = aws_scheduler_schedule_group.main.name
}

output "dlq_arn" {
  description = "ARN of the SQS dead-letter queue shared by all REDCap exporter Lambdas."
  value       = aws_sqs_queue.redcap_exporter_dlq.arn
}
