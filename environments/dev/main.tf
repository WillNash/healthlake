module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = "dev"
}

module "ingestion" {
  source = "../../modules/ingestion"

  project_name               = var.project_name
  environment                = "dev"
  kms_key_arn                = module.security.kms_key_arn
  redcap_url                 = var.redcap_url
  redcap_project_id          = var.redcap_project_id
  export_schedule_expression = var.export_schedule_expression
}

module "persistence" {
  source = "../../modules/persistence"

  providers = {
    aws   = aws
    awscc = awscc
  }

  project_name       = var.project_name
  environment        = "dev"
  landing_bucket_arn = module.ingestion.landing_bucket_arn
}

module "transformation" {
  source = "../../modules/transformation"

  project_name                    = var.project_name
  environment                     = "dev"
  kms_key_arn                     = module.security.kms_key_arn
  datastore_id                    = module.persistence.datastore_id
  datastore_endpoint              = module.persistence.datastore_endpoint
  datastore_arn                   = module.persistence.datastore_arn
  landing_bucket_name             = module.ingestion.landing_bucket_name
  landing_bucket_arn              = module.ingestion.landing_bucket_arn
  import_output_bucket_name       = module.persistence.import_output_bucket_name
  healthlake_data_access_role_arn = module.persistence.healthlake_data_access_role_arn
  registry_map                    = var.registry_map
}
