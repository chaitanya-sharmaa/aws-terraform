resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project_name}-${var.environment}-${var.app_name}-${random_id.bucket_suffix.hex}"
}

# ── S3 Bucket (Conditional) ───────────────────────────────────
resource "aws_s3_bucket" "static" {
  count         = var.enable_s3_origin ? 1 : 0
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-${var.app_name}"
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  count  = var.enable_s3_origin ? 1 : 0
  bucket = aws_s3_bucket.static[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "static" {
  count  = var.enable_s3_origin ? 1 : 0
  bucket = aws_s3_bucket.static[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudfront_origin_access_control" "static" {
  count                             = var.enable_s3_origin ? 1 : 0
  name                              = "${var.project_name}-${var.environment}-${var.app_name}-oac"
  description                       = "OAC for ${var.app_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "static" {
  count  = var.enable_s3_origin ? 1 : 0
  bucket = aws_s3_bucket.static[0].id
  policy = data.aws_iam_policy_document.s3_cloudfront[0].json

  depends_on = [aws_s3_bucket_public_access_block.static]
}

data "aws_iam_policy_document" "s3_cloudfront" {
  count = var.enable_s3_origin ? 1 : 0
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static[0].arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.app.arn]
    }
  }
}

# ── CloudFront VPC Origin (Always Created) ────────────────────
resource "aws_cloudfront_vpc_origin" "backend" {
  vpc_origin_endpoint_config {
    name                   = "${var.project_name}-${var.environment}-${var.app_name}-vpc-origin"
    arn                    = var.internal_alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}

# ── CloudFront Distribution ───────────────────────────────────
resource "aws_cloudfront_distribution" "app" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-${var.environment} ${var.app_name}"

  # Only set default root object if it's the static app (S3 origin)
  default_root_object = var.enable_s3_origin ? "index.html" : null

  # Conditional S3 Origin
  dynamic "origin" {
    for_each = var.enable_s3_origin ? [1] : []
    content {
      domain_name              = aws_s3_bucket.static[0].bucket_regional_domain_name
      origin_id                = "S3-${local.bucket_name}"
      origin_access_control_id = aws_cloudfront_origin_access_control.static[0].id
    }
  }

  # Always include the VPC origin (for /api or SSR)
  origin {
    domain_name = "${aws_cloudfront_vpc_origin.backend.vpc_origin_endpoint_config[0].name}.local"
    origin_id   = "VPC-Backend"

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.backend.id
    }

    custom_header {
      name  = "X-App-Name"
      value = var.app_name
    }
  }

  # Default Cache Behavior
  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # If S3 is enabled, S3 is default. Otherwise, VPC-Backend is default.
    target_origin_id = var.enable_s3_origin ? "S3-${local.bucket_name}" : "VPC-Backend"

    forwarded_values {
      # If S3 is default, don't forward query strings. If VPC-Backend, we probably want to forward them.
      query_string = var.enable_s3_origin ? false : true
      headers      = var.enable_s3_origin ? [] : ["Authorization", "Host"]
      cookies {
        forward = var.enable_s3_origin ? "none" : "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    # If using VPC-Backend for SSR, cache TTL should be 0 unless explicitly configured.
    # If S3, we can cache.
    min_ttl     = 0
    default_ttl = var.enable_s3_origin ? 3600 : 0
    max_ttl     = var.enable_s3_origin ? 86400 : 0
    compress    = true
  }

  # API Cache Behavior (Only needed if S3 is the default origin)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_s3_origin ? ["/api/*", "/axon/*", "/sre/*", "/v1/*"] : []
    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "VPC-Backend"

      forwarded_values {
        query_string = true
        headers      = ["Authorization"]
        cookies {
          forward = "all"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    }
  }

  # Health Cache Behavior (Only needed if S3 is the default origin)
  dynamic "ordered_cache_behavior" {
    for_each = var.enable_s3_origin ? [1] : []
    content {
      path_pattern     = "/health"
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "VPC-Backend"

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }

      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 0
      max_ttl                = 0
    }
  }

  # Custom Error Responses (Only makes sense for SPA / S3)
  dynamic "custom_error_response" {
    for_each = var.enable_s3_origin ? [1] : []
    content {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  }

  dynamic "custom_error_response" {
    for_each = var.enable_s3_origin ? [1] : []
    content {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    }
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
    Name = "${var.project_name}-${var.environment}-${var.app_name}"
  }
}
