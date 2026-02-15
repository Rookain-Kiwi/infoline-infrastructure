# ==============================================================================
# OUTPUTS - InfoLine Infrastructure
# ==============================================================================
# Agrège et expose les outputs de tous les modules pour :
#   - La configuration post-déploiement (kubectl, docker login)
#   - Les pipelines GitHub Actions (ECR URLs, EKS endpoint)
#   - Le backend Spring Boot (RDS connection string)
#   - Les scripts de validation (validate-infra.sh)
#
# ==============================================================================

# ==============================================================================
# VPC
# ==============================================================================

# Identifiant du VPC — référence principale pour tous les audits réseau
# et les commandes "aws ec2 describe-*" filtrées par VPC.
output "vpc_id" {
  description = "ID du VPC principal InfoLine"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Plage d'adresses IP du VPC (10.0.0.0/16)"
  value       = module.vpc.vpc_cidr
}

# Liste des 3 IDs de subnets privés — utilisés dans les manifests Kubernetes
# et les configurations d'autoscaling EKS.
output "private_subnet_ids" {
  description = "IDs des 3 subnets privés (worker nodes EKS)"
  value       = module.vpc.private_subnet_ids
}

# Liste des 3 IDs de subnets publics — référencés pour la configuration
# des LoadBalancers Kubernetes.
output "public_subnet_ids" {
  description = "IDs des 3 subnets publics (LoadBalancers, NAT Gateways)"
  value       = module.vpc.public_subnet_ids
}

# ==============================================================================
# EKS
# ==============================================================================

# Nom du cluster — paramètre central utilisé dans toutes les commandes :
# kubectl, aws eks, helm, et les scripts startup/shutdown/validate.
output "eks_cluster_name" {
  description = "Nom du cluster EKS"
  value       = module.eks.cluster_name
}

# URL HTTPS de l'API server — configurée dans kubeconfig et dans les
# providers Terraform kubernetes/helm (voir provider.tf).
output "eks_cluster_endpoint" {
  description = "Endpoint HTTPS de l'API server EKS"
  value       = module.eks.cluster_endpoint
}

# SG du control plane — référencé pour auditer les règles d'accès
# à l'API server et vérifier la règle ingress 443 depuis les nodes.
output "eks_cluster_security_group_id" {
  description = "ID du security group du control plane EKS"
  value       = module.eks.cluster_security_group_id
}

# SG des worker nodes — référencé par le module RDS pour la règle
# ingress PostgreSQL 5432 (accès DB depuis les pods uniquement).
output "eks_node_security_group_id" {
  description = "ID du security group des worker nodes EKS"
  value       = module.eks.node_security_group_id
}

# Commande prête à l'emploi pour configurer kubectl après un apply.
# À exécuter une fois le cluster déployé pour accéder au cluster
output "configure_kubectl" {
  description = "Commande aws eks update-kubeconfig à exécuter après apply"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Résumé consolidé du déploiement — affiché en fin d'apply pour
# validation rapide et utilisé dans les captures d'écran ECF (Phase 1).
output "deployment_info" {
  description = "Résumé du déploiement pour validation Phase 1"
  value = {
    region         = var.aws_region
    environment    = var.environment
    eks_cluster    = module.eks.cluster_name
    vpc_id         = module.vpc.vpc_id
    nodes_deployed = "${var.node_desired_size} worker nodes"
  }
}

# ==============================================================================
# RDS PostgreSQL
# ==============================================================================

# Endpoint complet (host:port) — injecté dans les variables d'environnement
# du pod backend via un Secret Kubernetes (SPRING_DATASOURCE_URL).
output "rds_endpoint" {
  description = "Endpoint RDS complet (host:port)"
  value       = module.rds.db_instance_endpoint
}

# Hostname seul — utilisé quand l'application configure host et port
# séparément (Spring Boot datasource properties).
output "rds_address" {
  description = "Hostname RDS (sans port)"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "Port PostgreSQL (5432)"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "Nom de la base de données PostgreSQL"
  value       = module.rds.db_name
}

# JDBC URL pour Spring Boot
# À compléter avec les credentials depuis le Secret Kubernetes.
output "rds_connection_string" {
  description = "JDBC connection string pour Spring Boot (sans credentials)"
  value       = module.rds.db_connection_string
}

# URL standard PostgreSQL — pour psql, pgAdmin et les scripts de validation.
output "rds_connection_url" {
  description = "URL PostgreSQL standard (sans credentials)"
  value       = module.rds.db_connection_url
}

# ID du SG RDS — pour auditer les règles d'accès et vérifier
# que seul le SG EKS est autorisé en ingress sur le port 5432.
output "rds_security_group_id" {
  description = "ID du security group RDS"
  value       = module.rds.db_security_group_id
}

# ==============================================================================
# ECR - Backend
# ==============================================================================

# URL complète du dépôt backend — utilisée dans le workflow GitHub Actions
# Et dans le manifest Kubernetes deployment.
output "ecr_backend_repository_url" {
  description = "URL ECR backend pour docker push et manifests Kubernetes"
  value       = module.ecr.repository_url
}

output "ecr_backend_repository_name" {
  description = "Nom du dépôt ECR backend"
  value       = module.ecr.repository_name
}

# Registry ID = Account ID AWS — nécessaire pour la commande docker login ECR
output "ecr_backend_registry_id" {
  description = "Registry ID ECR backend (= AWS Account ID)"
  value       = module.ecr.registry_id
}

# ==============================================================================
# ECR - Frontend
# ==============================================================================

# URL du dépôt frontend — même usage que le backend mais pour
# le pipeline CI/CD Angular et le manifest Kubernetes frontend.
output "ecr_frontend_repository_url" {
  description = "URL ECR frontend pour docker push et manifests Kubernetes"
  value       = module.ecr.frontend_repository_url
}

output "ecr_frontend_repository_name" {
  description = "Nom du dépôt ECR frontend"
  value       = module.ecr.frontend_repository_name
}

# ==============================================================================
# EBS CSI Driver
# ==============================================================================

# ARN du rôle IRSA — passé au chart Helm EBS CSI Driver dans startup-infra.sh
# pour annoter le ServiceAccount K8s et activer l'accès AWS EBS depuis les pods.
# Récupéré dynamiquement dans le script
output "ebs_csi_driver_role_arn" {
  description = "ARN du rôle IRSA pour l'EBS CSI Driver (utilisé par startup-infra.sh)"
  value       = module.eks.ebs_csi_driver_role_arn
}

# ==============================================================================
# Lambda
# ==============================================================================

# Nom de la fonction — utilisé dans validate-infra.sh pour tester
# l'invocation CLI
output "lambda_function_name" {
  description = "Nom de la fonction Lambda d'authentification"
  value       = module.lambda.lambda_function_name
}

# URL HTTPS publique de la fonction — provisionnée pour l'architecture cible.
# Invocation navigateur bloquée par SCP AWS Education — validée via CLI.
output "lambda_function_url" {
  description = "URL publique Lambda (invocation CLI validée, navigateur bloqué par SCP)"
  value       = module.lambda.lambda_function_url
}