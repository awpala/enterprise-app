output "user_pool_id" {
  description = "Cognito user pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "authority" {
  description = "OIDC issuer used by token validation."
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

output "client_id" {
  description = "Public UI app-client ID."
  value       = aws_cognito_user_pool_client.ui.id
}

output "api_audience" {
  description = "Cognito app-client ID checked against access-token client_id."
  value       = aws_cognito_user_pool_client.ui.id
}

output "api_scope" {
  description = "Fully qualified API OAuth scope."
  value       = "${aws_cognito_resource_server.api.identifier}/access_as_user"
}

output "managed_login_url" {
  description = "Cognito managed-login domain origin."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.aws_region}.amazoncognito.com"
}
