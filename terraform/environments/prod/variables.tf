variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "sa-east-1"
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}
