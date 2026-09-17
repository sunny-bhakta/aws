variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform"
  type        = string
  default     = "devops-local"
}

variable "project_name" {
  description = "Project name prefix used in resource naming"
  type        = string
  default     = "devops-nestjs"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "devops-nestjs-app"
}

variable "container_name" {
  description = "Container name in ECS task definition"
  type        = string
  default     = "devops-nestjs-app"
}

variable "container_port" {
  description = "Application container port"
  type        = number
  default     = 3000
}

variable "container_image_tag" {
  description = "Image tag deployed by ECS service"
  type        = string
  default     = "latest"
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

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired ECS service task count"
  type        = number
  default     = 1
}

variable "log_group_name" {
  description = "CloudWatch log group for ECS task logs"
  type        = string
  default     = "/aws/ecs/devops-nestjs-app"
}

variable "enable_rds" {
  description = "Create PostgreSQL RDS resources (can incur cost)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "appuser"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.7"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB"
  type        = number
  default     = 20
}

variable "enable_secrets" {
  description = "Create Secrets Manager secret for database config"
  type        = bool
  default     = false
}

variable "db_secret_name" {
  description = "Secrets Manager secret name"
  type        = string
  default     = "devops-nestjs/database"
}

variable "db_host_override" {
  description = "DB host used in secret when RDS is disabled"
  type        = string
  default     = ""
}

variable "db_password_override" {
  description = "DB password used in secret when RDS is disabled"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub owner/org name"
  type        = string
  default     = "sunny-bhakta"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "aws"
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the deploy role"
  type        = string
  default     = "main"
}

variable "github_owner_id" {
  description = "Optional GitHub owner numeric id for subject format with ids"
  type        = string
  default     = ""
}

variable "github_repo_id" {
  description = "Optional GitHub repository numeric id for subject format with ids"
  type        = string
  default     = ""
}

variable "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions OIDC"
  type        = string
  default     = "github-actions-ecr-push"
}