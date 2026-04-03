terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Local state for now (S3 backend later when permissions are granted)
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "palavracadabra"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# --- Networking ---

module "networking" {
  source = "../../modules/networking"

  project     = var.project_name
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

# --- Database ---

module "database" {
  source = "../../modules/database"

  project                    = var.project_name
  environment                = var.environment
  private_subnet_ids         = module.networking.private_subnet_ids
  database_security_group_id = module.networking.database_security_group_id
  db_instance_class          = var.db_instance_class
  db_username                = var.db_username
  db_password                = var.db_password
  redis_node_type            = var.redis_node_type
}

# --- Compute ---

module "compute" {
  source = "../../modules/compute"

  project               = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.networking.alb_security_group_id
  ecs_security_group_id = module.networking.ecs_security_group_id
  desired_count         = var.api_desired_count
  cpu                   = var.api_cpu
  memory                = var.api_memory
  database_url          = "postgresql+asyncpg://${var.db_username}:${var.db_password}@${module.database.postgres_endpoint}/${var.project_name}"
  redis_url             = "redis://${module.database.redis_endpoint}:6379"
}

# --- Storage ---

module "storage" {
  source = "../../modules/storage"

  project     = var.project_name
  environment = var.environment
}

# --- Auth ---

module "auth" {
  source = "../../modules/auth"

  project     = var.project_name
  environment = var.environment
}

# --- Outputs ---

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name for the API"
  value       = module.compute.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for API images"
  value       = module.compute.ecr_repository_url
}

output "postgres_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.postgres_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.database.redis_endpoint
  sensitive   = true
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain for assets"
  value       = module.storage.cloudfront_domain_name
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.auth.user_pool_id
}

output "cognito_mobile_client_id" {
  description = "Cognito mobile app client ID"
  value       = module.auth.mobile_client_id
}

output "cognito_web_client_id" {
  description = "Cognito web portal client ID"
  value       = module.auth.web_client_id
}
