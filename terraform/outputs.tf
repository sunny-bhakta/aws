output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.app.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group used by ECS task logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "rds_endpoint" {
  description = "PostgreSQL endpoint when RDS is enabled"
  value       = try(aws_db_instance.postgres[0].address, null)
}

output "db_secret_arn" {
  description = "Secrets Manager ARN when secret creation is enabled"
  value       = try(aws_secretsmanager_secret.db[0].arn, null)
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC"
  value       = aws_iam_role.github_actions.arn
}