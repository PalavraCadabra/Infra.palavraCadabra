variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "palavracadabra"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  default     = "palavracadabra"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "api_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "Desired number of ECS API tasks"
  type        = number
  default     = 1
}

variable "domain_name" {
  description = "Domain name for the project"
  type        = string
  default     = "palavracadabra.edu.br"
}
