output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "AWS-generated CloudFront domain name."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "application_url" {
  description = "AWS-generated HTTPS application origin."
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}
