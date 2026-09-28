output "analytics_bucket_name" {
  description = "Name of the S3 analytics bucket storing Iceberg Parquet tables."
  value       = aws_s3_bucket.analytics.bucket
}

output "analytics_bucket_arn" {
  description = "ARN of the S3 analytics bucket."
  value       = aws_s3_bucket.analytics.arn
}

output "athena_results_bucket_name" {
  description = "Name of the S3 bucket that stores Athena query results."
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for FHIR analytics queries."
  value       = aws_athena_workgroup.fhir_analytics.name
}

output "glue_database_name" {
  description = "Name of the Glue catalog database (also the Athena database)."
  value       = aws_glue_catalog_database.fhir.name
}

output "glue_etl_job_name" {
  description = "Name of the Glue ETL job that converts FHIR NDJSON to Iceberg Parquet."
  value       = aws_glue_job.fhir_to_iceberg.name
}

output "export_etl_sfn_arn" {
  description = "ARN of the export ETL orchestrator Step Functions state machine."
  value       = aws_sfn_state_machine.export_etl_orchestrator.arn
}

output "export_chain_trigger_lambda_arn" {
  description = "ARN of the export_chain_trigger Lambda. Pass this into the transformation module as analytics_export_trigger_lambda_arn."
  value       = aws_lambda_function.export_chain_trigger.arn
}

output "iceberg_compaction_role_arn" {
  description = "ARN of the IAM role used for Iceberg VACUUM/OPTIMIZE operations. Bypasses Lake Formation."
  value       = aws_iam_role.iceberg_compaction.arn
}
