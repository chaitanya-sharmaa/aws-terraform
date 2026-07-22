variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "internal_alb_arn" {
  description = "ARN of the internal Application Load Balancer for VPC Origin"
  type        = string
}

variable "app_name" {
  description = "Name of the application (e.g., static-app, dynamic-app)"
  type        = string
}

variable "enable_s3_origin" {
  description = "If true, creates an S3 bucket and uses it for default route (/*). If false, routes everything to the ALB."
  type        = bool
  default     = true
}
