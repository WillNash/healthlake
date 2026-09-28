# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# The analytics module exposes athena_results_bucket_name but the visualization
# module requires athena_results_bucket_arn. Construct the ARN from the name
# rather than duplicating the output in the analytics module.
locals {
  athena_results_bucket_arn = "arn:aws:s3:::${module.analytics.athena_results_bucket_name}"
}

# ---------------------------------------------------------------------------
# module.security
# No module dependencies — always applied first. Produces the KMS CMK and
# the audit/compliance baseline (CloudTrail, GuardDuty, Macie, Security Hub).
# ---------------------------------------------------------------------------
module "security" {
  source = "../../modules/security"

  project_name       = var.project_name
  environment        = "dev"
  enable_guardduty   = var.enable_guardduty
  enable_macie       = var.enable_macie
  enable_securityhub = var.enable_securityhub
}

# ---------------------------------------------------------------------------
# module.networking
# The kms_key_arn reference creates an implicit dependency on module.security.
# ---------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = "dev"
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  kms_key_arn          = module.security.kms_key_arn
}

# ---------------------------------------------------------------------------
# module.ingestion
# References from security and networking create implicit ordering.
# ---------------------------------------------------------------------------
module "ingestion" {
  source = "../../modules/ingestion"

  project_name              = var.project_name
  environment               = "dev"
  kms_key_arn               = module.security.kms_key_arn
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  lambda_security_group_id  = module.networking.lambda_security_group_id
  redcap_url                = var.redcap_url
  redcap_project_id         = var.redcap_project_id
  export_schedule_expression = var.export_schedule_expression
}

# ---------------------------------------------------------------------------
# module.persistence
# The awscc provider must be passed explicitly because this module creates
# awscc_healthlake_fhir_datastore resources and cannot inherit a default
# provider alias from the root module.
# The landing_bucket_arn reference creates an implicit dependency on
# module.ingestion.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# module.visualization
# Called before module.analytics so that quicksight_service_role_arn can be
# passed into analytics for Lake Formation grants. Terraform resolves the
# reference graph correctly regardless of HCL block order.
# ---------------------------------------------------------------------------
module "visualization" {
  source = "../../modules/visualization"

  project_name                   = var.project_name
  environment                    = "dev"
  kms_key_arn                    = module.security.kms_key_arn
  vpc_id                         = module.networking.vpc_id
  private_subnet_ids             = module.networking.private_subnet_ids
  vpc_endpoint_security_group_id = module.networking.vpc_endpoint_security_group_id
  analytics_bucket_arn           = module.analytics.analytics_bucket_arn
  athena_results_bucket_arn      = local.athena_results_bucket_arn
  athena_workgroup_name          = module.analytics.athena_workgroup_name
  glue_database_name             = module.analytics.glue_database_name
  create_subscription            = var.create_quicksight_subscription
  notification_email             = var.notification_email
  # Dev does not provision QuickSight VPC connectivity by default — no NAT
  # Gateway means direct private-subnet-to-QuickSight routing is unavailable.
  enable_vpc_connection = false
}

# ---------------------------------------------------------------------------
# module.ml
# Called before module.analytics so that sagemaker_execution_role_arn can be
# passed into analytics for Lake Formation grants.
# ---------------------------------------------------------------------------
module "ml" {
  source = "../../modules/ml"

  project_name                = var.project_name
  environment                 = "dev"
  kms_key_arn                 = module.security.kms_key_arn
  vpc_id                      = module.networking.vpc_id
  private_subnet_ids          = module.networking.private_subnet_ids
  sagemaker_security_group_id = module.networking.sagemaker_security_group_id
  analytics_bucket_arn        = module.analytics.analytics_bucket_arn
  athena_workgroup_name       = module.analytics.athena_workgroup_name
  glue_database_name          = module.analytics.glue_database_name
  enable_sagemaker            = var.enable_sagemaker
  sagemaker_users             = var.sagemaker_users
}

# ---------------------------------------------------------------------------
# module.analytics
# Depends on persistence (datastore, export bucket), security (KMS), and
# networking (VPC). Also receives the IAM role ARNs from visualization and ml
# so it can grant Lake Formation permissions to those roles.
# ---------------------------------------------------------------------------
module "analytics" {
  source = "../../modules/analytics"

  project_name                 = var.project_name
  environment                  = "dev"
  kms_key_arn                  = module.security.kms_key_arn
  vpc_id                       = module.networking.vpc_id
  private_subnet_ids           = module.networking.private_subnet_ids
  lambda_security_group_id     = module.networking.lambda_security_group_id
  datastore_id                 = module.persistence.datastore_id
  fhir_export_bucket_name      = module.persistence.fhir_export_bucket_name
  fhir_export_bucket_arn       = module.persistence.fhir_export_bucket_arn
  healthlake_export_role_arn   = module.persistence.healthlake_export_role_arn
  glue_worker_count            = var.glue_worker_count
  additional_analyst_role_arns = var.additional_analyst_role_arns
  quicksight_service_role_arn  = module.visualization.quicksight_service_role_arn
  sagemaker_execution_role_arn = module.ml.sagemaker_execution_role_arn
}

# ---------------------------------------------------------------------------
# module.transformation
# The analytics_export_trigger_lambda_arn reference creates an implicit
# dependency on module.analytics. All other references depend on persistence
# and ingestion, which are already resolved before analytics can complete.
# ---------------------------------------------------------------------------
module "transformation" {
  source = "../../modules/transformation"

  project_name                        = var.project_name
  environment                         = "dev"
  kms_key_arn                         = module.security.kms_key_arn
  vpc_id                              = module.networking.vpc_id
  private_subnet_ids                  = module.networking.private_subnet_ids
  lambda_security_group_id            = module.networking.lambda_security_group_id
  datastore_id                        = module.persistence.datastore_id
  datastore_endpoint                  = module.persistence.datastore_endpoint
  datastore_arn                       = module.persistence.datastore_arn
  landing_bucket_name                 = module.ingestion.landing_bucket_name
  landing_bucket_arn                  = module.ingestion.landing_bucket_arn
  import_output_bucket_name           = module.persistence.import_output_bucket_name
  healthlake_data_access_role_arn     = module.persistence.healthlake_data_access_role_arn
  dta_profile_id                      = var.dta_profile_id
  comprehend_free_text_fields         = var.comprehend_free_text_fields
  analytics_export_trigger_lambda_arn = module.analytics.export_chain_trigger_lambda_arn
}
