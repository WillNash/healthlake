# Athena workgroup for FHIR analytics queries.
#
# NOTE: There is NO aws_athena_database resource in this file.
# The Glue catalog database (aws_glue_catalog_database.fhir in main.tf) IS the
# Athena database — Athena reads from the Glue Data Catalog natively.
# Creating a separate aws_athena_database would conflict with the Glue resource.

resource "aws_athena_workgroup" "fhir_analytics" {
  name          = "${var.project_name}-${var.environment}-fhir-analytics"
  force_destroy = false

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 10737418240 # 10 GB default; prevents runaway scans

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key           = var.kms_key_arn
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }
}
