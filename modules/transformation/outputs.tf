output "sfn_state_machine_arn" {
  description = "ARN of the import orchestrator Step Functions state machine."
  value       = aws_sfn_state_machine.import_orchestrator.arn
}

output "sfn_state_machine_name" {
  description = "Name of the import orchestrator Step Functions state machine."
  value       = aws_sfn_state_machine.import_orchestrator.name
}

output "import_launcher_lambda_arn" {
  description = "ARN of the import_launcher Lambda function."
  value       = aws_lambda_function.import_launcher.arn
}

output "import_poller_lambda_arn" {
  description = "ARN of the import_poller Lambda function."
  value       = aws_lambda_function.import_poller.arn
}

output "comprehend_processor_lambda_arn" {
  description = "ARN of the comprehend_processor Lambda function."
  value       = aws_lambda_function.comprehend_processor.arn
}

output "import_failures_sns_arn" {
  description = "ARN of the SNS topic that receives import failure notifications."
  value       = aws_sns_topic.import_failures.arn
}

output "dta_profile_ssm_parameter_name" {
  description = "Name of the SSM SecureString parameter that stores the DTA profile ID."
  value       = aws_ssm_parameter.dta_profile_id.name
}
