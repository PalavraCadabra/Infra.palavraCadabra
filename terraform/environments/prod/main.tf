terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "palavracadabra-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "palavracadabra-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "palavracadabra"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# --- Networking ---

module "networking" {
  source = "../../modules/networking"

  environment = "prod"
  vpc_cidr    = "10.1.0.0/16"
}

# --- Database ---

module "database" {
  source = "../../modules/database"

  environment                = "prod"
  private_subnet_ids         = module.networking.private_subnet_ids
  database_security_group_id = module.networking.database_security_group_id
  db_instance_class          = "db.t3.small"
  db_password                = var.db_password
  redis_node_type            = "cache.t3.small"
}

# --- Compute ---

module "compute" {
  source = "../../modules/compute"

  environment           = "prod"
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  app_security_group_id = module.networking.app_security_group_id
  desired_count         = 2
  cpu                   = 512
  memory                = 1024
}

# --- Storage ---

module "storage" {
  source = "../../modules/storage"

  environment = "prod"
}

# --- Auth ---

module "auth" {
  source = "../../modules/auth"

  environment = "prod"
}

# --- Outputs ---

output "vpc_id" {
  value = module.networking.vpc_id
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "postgres_endpoint" {
  value     = module.database.postgres_endpoint
  sensitive = true
}

output "redis_endpoint" {
  value     = module.database.redis_endpoint
  sensitive = true
}

output "cloudfront_domain" {
  value = module.storage.cloudfront_domain_name
}

output "cognito_user_pool_id" {
  value = module.auth.user_pool_id
}
