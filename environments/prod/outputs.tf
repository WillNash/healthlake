output "landing_bucket_name" {
  description = "Name of the S3 landing bucket that receives REDCap CSV exports."
  value       = module.ingestion.landing_bucket_name
}

output "healthlake_datastore_id" {
  description = "ID of the HealthLake FHIR R4 datastore."
  value       = module.persistence.datastore_id
}

output "healthlake_datastore_endpoint" {
  description = "FHIR REST API endpoint of the HealthLake datastore."
  value       = module.persistence.datastore_endpoint
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for FHIR analytics queries."
  value       = module.analytics.athena_workgroup_name
}

output "glue_database_name" {
  description = "Name of the Glue catalog database (also the Athena database)."
  value       = module.analytics.glue_database_name
}

output "analytics_bucket_name" {
  description = "Name of the S3 analytics bucket storing Iceberg Parquet tables."
  value       = module.analytics.analytics_bucket_name
}

output "export_etl_sfn_arn" {
  description = "ARN of the export ETL orchestrator Step Functions state machine."
  value       = module.analytics.export_etl_sfn_arn
}

output "import_orchestrator_sfn_arn" {
  description = "ARN of the import orchestrator Step Functions state machine."
  value       = module.transformation.sfn_state_machine_arn
}

output "quicksight_service_role_arn" {
  description = "ARN of the QuickSight service IAM role."
  value       = module.visualization.quicksight_service_role_arn
}

output "sagemaker_domain_id" {
  description = "ID of the SageMaker domain, or an empty string when enable_sagemaker = false."
  value       = module.ml.sagemaker_domain_id
}
