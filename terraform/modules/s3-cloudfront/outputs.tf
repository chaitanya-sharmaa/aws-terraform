output "bucket_name" {
  description = "S3 bucket name for the frontend (if S3 origin is enabled)"
  value       = try(aws_s3_bucket.static[0].bucket, null)
}

output "bucket_arn" {
  description = "S3 bucket ARN (if S3 origin is enabled)"
  value       = try(aws_s3_bucket.static[0].arn, null)
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name (e.g. abc123.cloudfront.net)"
  value       = aws_cloudfront_distribution.app.domain_name
}

output "distribution_id" {
  description = "CloudFront distribution ID (used for cache invalidation)"
  value       = aws_cloudfront_distribution.app.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.app.arn
}
