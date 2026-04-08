output "bucket_name" {
  description = "S3 bucket name used for static frontend hosting."
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution identifier for the static frontend."
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name for the static frontend."
  value       = aws_cloudfront_distribution.frontend.domain_name
}
