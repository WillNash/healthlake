output "landing_bucket_name" {
  description = "Name of the S3 landing bucket that receives REDCap CSV exports."
  value       = aws_s3_bucket.landing.id
}

output "landing_bucket_arn" {
  description = "ARN of the S3 landing bucket."
  value       = aws_s3_bucket.landing.arn
}

output "redcap_token_secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the REDCap API token."
  value       = aws_secretsmanager_secret.redcap_token.arn
}

output "redcap_exporter_lambda_arn" {
  description = "ARN of the REDCap exporter Lambda function."
  value       = aws_lambda_function.redcap_exporter.arn
}

output "scheduler_schedule_group_name" {
  description = "Name of the EventBridge Scheduler schedule group."
  value       = aws_scheduler_schedule_group.main.name
}

output "dlq_arn" {
  description = "ARN of the SQS dead-letter queue for the REDCap exporter Lambda."
  value       = aws_sqs_queue.redcap_exporter_dlq.arn
}
