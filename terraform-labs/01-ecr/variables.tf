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

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "devops-nestjs-app"
}