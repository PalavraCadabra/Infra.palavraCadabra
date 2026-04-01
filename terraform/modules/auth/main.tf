# =============================================================================
# Auth Module — palavraCadabra
# =============================================================================
# Provisions:
#   - Cognito User Pool for authentication (therapists, teachers, caregivers)
#   - Cognito User Pool Client for the mobile app (Flutter)
#   - Cognito User Pool Client for the web portal (Next.js)
#   - Custom attributes for user roles and institution association
#   - Password policy and MFA configuration
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

# --- Cognito User Pool ---

resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-${var.environment}"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  schema {
    name                = "role"
    attribute_data_type = "String"
    mutable             = true
    required            = false
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  schema {
    name                = "institution_id"
    attribute_data_type = "String"
    mutable             = true
    required            = false
    string_attribute_constraints {
      min_length = 0
      max_length = 36
    }
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# --- User Pool Client: Mobile App (Flutter) ---

resource "aws_cognito_user_pool_client" "mobile" {
  name         = "${var.project}-${var.environment}-mobile"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  access_token_validity  = 1    # hours
  id_token_validity      = 1    # hours
  refresh_token_validity = 30   # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# --- User Pool Client: Web Portal (Next.js) ---

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-${var.environment}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  callback_urls = var.environment == "prod" ? [
    "https://portal.palavracadabra.edu.br/api/auth/callback"
  ] : [
    "http://localhost:3000/api/auth/callback",
    "https://dev-portal.palavracadabra.edu.br/api/auth/callback"
  ]

  logout_urls = var.environment == "prod" ? [
    "https://portal.palavracadabra.edu.br"
  ] : [
    "http://localhost:3000",
    "https://dev-portal.palavracadabra.edu.br"
  ]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }
}

# --- Outputs ---

output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.main.arn
}

output "mobile_client_id" {
  value = aws_cognito_user_pool_client.mobile.id
}

output "web_client_id" {
  value = aws_cognito_user_pool_client.web.id
}
