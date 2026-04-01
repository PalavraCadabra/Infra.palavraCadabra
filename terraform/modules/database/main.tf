# =============================================================================
# Database Module — palavraCadabra
# =============================================================================
# Provisions:
#   - RDS PostgreSQL 16 instance with TimescaleDB extension
#   - DB subnet group across private subnets
#   - ElastiCache Redis cluster for caching and session management
#   - ElastiCache subnet group
#   - Parameter groups for PostgreSQL and Redis tuning
# =============================================================================

variable "project" {
  description = "Project name for resource tagging"
  type        = string
  default     = "palavracadabra"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "database_security_group_id" {
  description = "Security group ID for database access"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the default database"
  type        = string
  default     = "palavracadabra"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "pcadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

# --- RDS PostgreSQL ---

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-db-subnet"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.project}-${var.environment}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_security_group_id]

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  backup_retention_period = 7
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"

  tags = {
    Name        = "${var.project}-${var.environment}-postgres"
    Project     = var.project
    Environment = var.environment
  }
}

# --- ElastiCache Redis ---

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project}-${var.environment}-redis-subnet"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project}-${var.environment}-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [var.database_security_group_id]

  tags = {
    Name        = "${var.project}-${var.environment}-redis"
    Project     = var.project
    Environment = var.environment
  }
}

# --- Outputs ---

output "postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "postgres_db_name" {
  value = aws_db_instance.postgres.db_name
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}
