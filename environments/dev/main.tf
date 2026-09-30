module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = "dev"
}

module "ingestion" {
  source = "../../modules/ingestion"

  project_name    = var.project_name
  environment     = "dev"
  kms_key_arn     = module.security.kms_key_arn
  redcap_projects = var.redcap_projects
}

module "persistence" {
  source = "../../modules/persistence"

  providers = {
    aws   = aws
    awscc = awscc
  }

  project_name       = var.project_name
  environment        = "dev"
  healthlake_enabled = var.healthlake_enabled
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
  healthlake_kms_key_arn          = module.persistence.healthlake_kms_key_arn
  registry_map                    = var.registry_map
}
