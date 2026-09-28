output "quicksight_service_role_arn" {
  description = "ARN of the QuickSight service IAM role. Pass to the analytics module for Lake Formation grants."
  value       = aws_iam_role.quicksight_service.arn
}

output "quicksight_service_role_name" {
  description = "Name of the QuickSight service IAM role."
  value       = aws_iam_role.quicksight_service.name
}

output "quicksight_data_source_arn" {
  description = "ARN of the QuickSight Athena data source."
  # try() handles the rare case where the data source creation fails or is
  # removed from state in isolation — it prevents a hard plan error in callers.
  value = try(aws_quicksight_data_source.athena.arn, "")
}

output "quicksight_vpc_connection_arn" {
  description = "ARN of the QuickSight VPC connection, or an empty string when enable_vpc_connection = false."
  value       = var.enable_vpc_connection ? try(aws_quicksight_vpc_connection.main[0].arn, "") : ""
}
