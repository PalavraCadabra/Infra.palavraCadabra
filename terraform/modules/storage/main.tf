# =============================================================================
# Storage Module — palavraCadabra
# =============================================================================
# Provisions:
#   - S3 bucket for ARASAAC pictogram assets and user-uploaded media
#   - S3 bucket for static web assets (Next.js export)
#   - S3 bucket policies and CORS configuration
#   - CloudFront distribution for CDN delivery of assets
#   - CloudFront Origin Access Identity for secure S3 access
# =============================================================================

# --- Variables ---

variable "project" {
  description = "Project name for resource tagging"
  type        = string
  default     = "palavracadabra"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# --- S3: Assets Bucket (pictograms, media) ---

resource "aws_s3_bucket" "assets" {
  bucket = "${var.project}-${var.environment}-assets"

  tags = {
    Name = "${var.project}-${var.environment}-assets"
  }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- S3: Static Web Bucket ---

resource "aws_s3_bucket" "web" {
  bucket = "${var.project}-${var.environment}-web"

  tags = {
    Name = "${var.project}-${var.environment}-web"
  }
}

resource "aws_s3_bucket_public_access_block" "web" {
  bucket = aws_s3_bucket.web.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- CloudFront ---

resource "aws_cloudfront_origin_access_identity" "assets" {
  comment = "${var.project}-${var.environment} assets OAI"
}

# Bucket policy to allow CloudFront OAI access
resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.assets.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.assets.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

resource "aws_cloudfront_distribution" "assets" {
  origin {
    domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.assets.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.assets.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project}-${var.environment} assets CDN"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.assets.id}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project}-${var.environment}-assets-cdn"
  }
}

# --- Outputs ---

output "assets_bucket_name" {
  description = "Assets S3 bucket name"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "Assets S3 bucket ARN"
  value       = aws_s3_bucket.assets.arn
}

output "web_bucket_name" {
  description = "Web static files S3 bucket name"
  value       = aws_s3_bucket.web.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.assets.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.assets.id
}
