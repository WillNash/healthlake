# IMPORTANT: All Iceberg tables (aws_glue_catalog_table.fhir_resource) MUST be
# created BEFORE registering the analytics bucket with Lake Formation.
# Lake Formation blocks DDL on registered Iceberg tables from Athena.
# The depends_on below enforces this ordering.

resource "aws_lakeformation_resource" "analytics_bucket" {
  arn = aws_s3_bucket.analytics.arn

  depends_on = [aws_glue_catalog_table.fhir_resource]
}

# ── Lake Formation permissions ─────────────────────────────────────────────────
#
# Athena queries execute under the calling IAM identity's permissions.
# Permissions must be granted to the principals that actually run queries
# (QuickSight service role, SageMaker execution role, analyst roles),
# NOT to a "workgroup IAM role" — that concept does not exist in Lake Formation.

# Grant SELECT + DESCRIBE on every Iceberg table to QuickSight service role.
# Skipped when quicksight_service_role_arn is empty.
resource "aws_lakeformation_permissions" "quicksight_select" {
  for_each = var.quicksight_service_role_arn != "" ? toset(var.fhir_resource_tables) : toset([])

  principal   = var.quicksight_service_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.fhir.name
    name          = each.key
  }

  depends_on = [aws_lakeformation_resource.analytics_bucket]
}

# Grant SELECT + DESCRIBE on every Iceberg table to SageMaker execution role.
# Skipped when sagemaker_execution_role_arn is empty.
resource "aws_lakeformation_permissions" "sagemaker_select" {
  for_each = var.sagemaker_execution_role_arn != "" ? toset(var.fhir_resource_tables) : toset([])

  principal   = var.sagemaker_execution_role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.fhir.name
    name          = each.key
  }

  depends_on = [aws_lakeformation_resource.analytics_bucket]
}

# Grant SELECT + DESCRIBE on every Iceberg table to each additional analyst role.
# for_each key: "<role_arn>::<table_name>" to produce unique resource addresses.
resource "aws_lakeformation_permissions" "analyst_select" {
  for_each = {
    for pair in setproduct(var.additional_analyst_role_arns, var.fhir_resource_tables) :
    "${pair[0]}::${pair[1]}" => { role_arn = pair[0], table = pair[1] }
  }

  principal   = each.value.role_arn
  permissions = ["SELECT", "DESCRIBE"]

  table {
    database_name = aws_glue_catalog_database.fhir.name
    name          = each.value.table
  }

  depends_on = [aws_lakeformation_resource.analytics_bucket]
}

# Grant ALL on the Glue database and all tables to the Glue ETL role so it can
# write Iceberg data. This must NOT use Lake Formation row/cell filters on the
# tables used by the ETL job.
resource "aws_lakeformation_permissions" "glue_etl_database" {
  principal   = aws_iam_role.glue_etl.arn
  permissions = ["ALL"]

  database {
    name = aws_glue_catalog_database.fhir.name
  }

  depends_on = [aws_lakeformation_resource.analytics_bucket]
}

resource "aws_lakeformation_permissions" "glue_etl_tables" {
  for_each = toset(var.fhir_resource_tables)

  principal   = aws_iam_role.glue_etl.arn
  permissions = ["ALL"]

  table {
    database_name = aws_glue_catalog_database.fhir.name
    name          = each.key
  }

  depends_on = [aws_lakeformation_resource.analytics_bucket]
}
