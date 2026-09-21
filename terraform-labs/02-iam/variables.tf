variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "Local AWS profile"
  type        = string
  default     = "devops-local"
}

variable "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions OIDC"
  type        = string
  default     = "github-actions-ecr-push"
}

variable "github_owner" {
  description = "GitHub owner/org"
  type        = string
  default     = "sunny-bhakta"
}

variable "github_repo" {
  description = "GitHub repository"
  type        = string
  default     = "aws"
}

variable "github_branch" {
  description = "Allowed GitHub branch"
  type        = string
  default     = "main"
}

variable "github_owner_id" {
  description = "Optional GitHub owner id"
  type        = string
  default     = "77013204"
}

variable "github_repo_id" {
  description = "Optional GitHub repo id"
  type        = string
  default     = "1361501698"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "devops-nestjs-app"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "devops-cluster"
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "devops-nestjs-service"
}

variable "ecs_task_execution_role_name" {
  description = "Terraform-managed ECS task execution role name"
  type        = string
  default     = "devops-nestjs-ecs-task-execution-role"
}

variable "ecs_task_role_name" {
  description = "Terraform-managed ECS task role name"
  type        = string
  default     = "devops-nestjs-ecs-task-role"
}

variable "console_ecs_task_execution_role_name" {
  description = "Optional console/manual ECS task execution role name (leave empty if unused)"
  type        = string
  default     = ""
}
