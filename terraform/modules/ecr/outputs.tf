output "repository_url" {
  description = "URL du repository ECR backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "repository_name" {
  description = "Nom du repository ECR"
  value       = aws_ecr_repository.backend.name
}

output "registry_id" {
  description = "Registry ID du repository ECR"
  value       = aws_ecr_repository.backend.registry_id
}
