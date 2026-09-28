output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs. Pass to Lambda vpc_config and VPC endpoint subnet_ids."
  value       = tolist([for s in aws_subnet.private : s.id])
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (NAT Gateway placement only)."
  value       = tolist([for s in aws_subnet.public : s.id])
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group."
  value       = aws_security_group.lambda.id
}

output "flow_log_group_arn" {
  description = "ARN of the CloudWatch Log Group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

output "nat_gateway_ids" {
  description = "Map of AZ suffix to NAT Gateway ID. Empty map when enable_nat_gateway is false."
  value       = { for k, v in aws_nat_gateway.this : k => v.id }
}
