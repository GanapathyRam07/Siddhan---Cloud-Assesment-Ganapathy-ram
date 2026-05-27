variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "target_group_arn" { type = string }
variable "alb_sg_id" { type = string }
variable "app_port" { type = number }
variable "aws_region" { type = string }

variable "app_image" {
  type        = string
  description = "Docker image URI from ECR"
  default     = "public.ecr.aws/nginx/nginx:latest"  # ← fallback for first apply
}
