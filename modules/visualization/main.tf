data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# QuickSight account subscription
# Gate with count so re-applying to an already-subscribed account does not
# error. Set create_subscription = true only on first apply in a new account.
# ---------------------------------------------------------------------------
resource "aws_quicksight_account_subscription" "main" {
  count = var.create_subscription ? 1 : 0

  # ENTERPRISE is mandatory for HIPAA: VPC connectivity + row-level security
  edition             = "ENTERPRISE"
  authentication_method = "IAM_AND_QUICKSIGHT"
  account_name        = "${var.project_name}-${var.environment}"
  notification_email  = var.notification_email
}

# ---------------------------------------------------------------------------
# Security group for QuickSight VPC connection
# Egress: HTTPS (443) to the VPC endpoints security group only.
# No inbound rules — QuickSight initiates all connections outbound.
# ---------------------------------------------------------------------------
resource "aws_security_group" "quicksight" {
  name        = "${var.project_name}-${var.environment}-quicksight"
  description = "QuickSight VPC connection egress to VPC endpoints only."
  vpc_id      = var.vpc_id

  egress {
    description              = "HTTPS to VPC endpoints"
    from_port                = 443
    to_port                  = 443
    protocol                 = "tcp"
    security_groups          = [var.vpc_endpoint_security_group_id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-quicksight"
  }
}

# ---------------------------------------------------------------------------
# QuickSight VPC connection
# Enables QuickSight to reach Athena via the private VPC (no internet path).
# Gated — disable in dev environments that lack private connectivity.
# ---------------------------------------------------------------------------
resource "aws_quicksight_vpc_connection" "main" {
  count = var.enable_vpc_connection ? 1 : 0

  vpc_connection_id  = "${var.project_name}-${var.environment}"
  name               = "${var.project_name}-${var.environment}"
  role_arn           = aws_iam_role.quicksight_service.arn
  security_group_ids = [aws_security_group.quicksight.id]
  subnet_ids         = var.private_subnet_ids
}

# ---------------------------------------------------------------------------
# QuickSight Athena data source
# ssl_properties.disable_ssl = false enforces TLS on all Athena connections.
# vpc_connection_properties block is included only when the VPC connection
# is enabled, keeping the data source usable in dev without VPC connectivity.
# ---------------------------------------------------------------------------
resource "aws_quicksight_data_source" "athena" {
  data_source_id = "${var.project_name}-${var.environment}-athena"
  name           = "FHIR Registry Athena"
  type           = "ATHENA"

  parameters {
    athena {
      work_group = var.athena_workgroup_name
    }
  }

  ssl_properties {
    disable_ssl = false
  }

  dynamic "vpc_connection_properties" {
    for_each = var.enable_vpc_connection ? [1] : []

    content {
      vpc_connection_arn = aws_quicksight_vpc_connection.main[0].arn
    }
  }

  # Grant the admin user permissions on this data source when one is supplied.
  dynamic "permission" {
    for_each = var.admin_quicksight_user != "" ? [var.admin_quicksight_user] : []

    content {
      principal = "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:user/default/${permission.value}"
      actions = [
        "quicksight:DescribeDataSource",
        "quicksight:DescribeDataSourcePermissions",
        "quicksight:PassDataSource",
        "quicksight:UpdateDataSource",
        "quicksight:DeleteDataSource",
        "quicksight:UpdateDataSourcePermissions",
      ]
    }
  }

  depends_on = [aws_quicksight_account_subscription.main]
}
