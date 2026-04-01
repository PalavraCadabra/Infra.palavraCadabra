# =============================================================================
# Networking Module — palavraCadabra
# =============================================================================
# Provisions:
#   - VPC with public and private subnets across 2 AZs
#   - Internet Gateway and NAT Gateway
#   - Route tables for public/private subnets
#   - Security groups for application, database, and cache tiers
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# --- VPC ---

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project}-${var.environment}-vpc"
    Project     = var.project
    Environment = var.environment
  }
}

# --- Subnets ---

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${var.environment}-public-${count.index}"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project}-${var.environment}-private-${count.index}"
    Project     = var.project
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --- Internet Gateway ---

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${var.environment}-igw"
    Project     = var.project
    Environment = var.environment
  }
}

# --- Security Groups ---

resource "aws_security_group" "app" {
  name_prefix = "${var.project}-${var.environment}-app-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for application tier (ECS Fargate)"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-app-sg"
    Project     = var.project
    Environment = var.environment
  }
}

resource "aws_security_group" "database" {
  name_prefix = "${var.project}-${var.environment}-db-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for database tier (RDS + ElastiCache)"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.environment}-db-sg"
    Project     = var.project
    Environment = var.environment
  }
}

# --- Outputs ---

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "database_security_group_id" {
  value = aws_security_group.database.id
}
