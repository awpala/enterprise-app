output "repository_urls" {
  description = "Repository URLs keyed by cloud-neutral logical image name."
  value       = { for name, repository in aws_ecr_repository.this : name => repository.repository_url }
}
