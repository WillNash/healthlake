module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = "prod"
}

module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = "prod"
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  kms_key_arn          = module.security.kms_key_arn
}

module "ingestion" {
  source = "../../modules/ingestion"

  project_name               = var.project_name
  environment                = "prod"
  kms_key_arn                = module.security.kms_key_arn
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  lambda_security_group_id   = module.networking.lambda_security_group_id
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
  environment        = "prod"
  landing_bucket_arn = module.ingestion.landing_bucket_arn
}

module "transformation" {
  source = "../../modules/transformation"

  project_name                    = var.project_name
  environment                     = "prod"
  kms_key_arn                     = module.security.kms_key_arn
  vpc_id                          = module.networking.vpc_id
  private_subnet_ids              = module.networking.private_subnet_ids
  lambda_security_group_id        = module.networking.lambda_security_group_id
  datastore_id                    = module.persistence.datastore_id
  datastore_endpoint              = module.persistence.datastore_endpoint
  datastore_arn                   = module.persistence.datastore_arn
  landing_bucket_name             = module.ingestion.landing_bucket_name
  landing_bucket_arn              = module.ingestion.landing_bucket_arn
  import_output_bucket_name       = module.persistence.import_output_bucket_name
  healthlake_data_access_role_arn = module.persistence.healthlake_data_access_role_arn
  registry_map                    = var.registry_map
}
