# ==============================================================================
# OUTPUTS - Module ECR
# ==============================================================================
# Expose les attributs des dépôts ECR pour les modules qui les consomment.
# Utilisés principalement par :
#   - Les pipelines GitHub Actions
#   - Les manifests Kubernetes
# ==============================================================================

# ------------------------------------------------------------------------------
# Backend
# ------------------------------------------------------------------------------

# URL complète du dépôt : <account_id>.dkr.ecr.eu-west-3.amazonaws.com/infoline-backend
# Utilisée dans le workflow CI/CD backend pour le docker build/push
# et dans le manifest Kubernetes deployment du backend.
output "repository_url" {
  description = "URL du repository ECR backend"
  value       = aws_ecr_repository.backend.repository_url
}

# Nom court du dépôt — utilisé pour construire les commandes
# aws ecr get-login-password et aws ecr describe-images dans les scripts.
output "repository_name" {
  description = "Nom du repository ECR backend"
  value       = aws_ecr_repository.backend.name
}

# ID du registre ECR = ID du compte AWS (12 chiffres).
# Nécessaire pour construire l'URL de login ECR :
#   aws ecr get-login-password | docker login --username AWS \
#     --password-stdin <registry_id>.dkr.ecr.<region>.amazonaws.com
output "registry_id" {
  description = "Registry ID du repository ECR backend (= AWS Account ID)"
  value       = aws_ecr_repository.backend.registry_id
}

# ------------------------------------------------------------------------------
# Frontend
# ------------------------------------------------------------------------------

# URL complète du dépôt frontend — même usage que repository_url backend
# mais pour le pipeline CI/CD Angular et le manifest Kubernetes frontend.
output "frontend_repository_url" {
  description = "URL du repository ECR frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "frontend_repository_name" {
  description = "Nom du repository ECR frontend"
  value       = aws_ecr_repository.frontend.name
}

# registry_id identique au backend (même compte AWS) — exposé séparément
# pour permettre une consommation indépendante des outputs par module.
output "frontend_registry_id" {
  description = "Registry ID du repository ECR frontend (= AWS Account ID)"
  value       = aws_ecr_repository.frontend.registry_id
}