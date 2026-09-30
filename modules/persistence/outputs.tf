output "datastore_id" {
  description = "ID of the HealthLake FHIR R4 datastore. Empty string when healthlake_enabled is false."
  value       = var.healthlake_enabled ? awscc_healthlake_fhir_datastore.main[0].datastore_id : ""
}

output "datastore_arn" {
  description = "ARN of the HealthLake FHIR R4 datastore. Returns \"*\" when healthlake_enabled is false so downstream IAM policies remain valid."
  value       = var.healthlake_enabled ? awscc_healthlake_fhir_datastore.main[0].datastore_arn : "*"
}

output "datastore_endpoint" {
  description = "FHIR REST API endpoint of the HealthLake datastore. Empty string when healthlake_enabled is false."
  value       = var.healthlake_enabled ? awscc_healthlake_fhir_datastore.main[0].datastore_endpoint : ""
}

output "healthlake_kms_key_arn" {
  description = "ARN of the dedicated KMS key used to encrypt the HealthLake datastore and its associated S3 buckets."
  value       = aws_kms_key.healthlake.arn
}

output "healthlake_data_access_role_arn" {
  description = "ARN of the IAM role passed as --data-access-role-arn when starting a HealthLake FHIR import job."
  value       = aws_iam_role.healthlake_data_access.arn
}

output "healthlake_export_role_arn" {
  description = "ARN of the IAM role used by HealthLake bulk export jobs to write to the FHIR export bucket."
  value       = aws_iam_role.healthlake_export.arn
}

output "fhir_export_bucket_name" {
  description = "Name of the S3 bucket that receives HealthLake bulk export output."
  value       = aws_s3_bucket.fhir_export.id
}

output "fhir_export_bucket_arn" {
  description = "ARN of the S3 bucket that receives HealthLake bulk export output."
  value       = aws_s3_bucket.fhir_export.arn
}

output "import_output_bucket_name" {
  description = "Name of the S3 bucket that receives import job provenance and FHIR NDJSON output."
  value       = aws_s3_bucket.import_output.id
}

output "import_output_bucket_arn" {
  description = "ARN of the S3 bucket that receives import job provenance and FHIR NDJSON output."
  value       = aws_s3_bucket.import_output.arn
}
