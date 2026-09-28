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

output "fhir_staging_bucket_name" {
  description = "Name of the S3 staging bucket holding FHIR NDJSON between the mapper and the HealthLake import job."
  value       = module.transformation.fhir_staging_bucket_name
}

output "import_orchestrator_sfn_arn" {
  description = "ARN of the import orchestrator Step Functions state machine."
  value       = module.transformation.sfn_state_machine_arn
}

output "import_failures_sns_arn" {
  description = "ARN of the SNS topic that receives import failure notifications."
  value       = module.transformation.import_failures_sns_arn
}
