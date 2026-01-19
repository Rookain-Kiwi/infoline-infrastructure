# ============================================================================
# Outputs - VPC + EKS
# ============================================================================

# VPC Outputs
output "vpc_id" {
  description = "ID du VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR du VPC"
  value       = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs des subnets privés"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs des subnets publics"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Nom du cluster EKS"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint du cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Security group du cluster EKS"
  value       = module.eks.cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "Security group des nodes EKS"
  value       = module.eks.node_security_group_id
}

# Commande pour configurer kubectl
output "configure_kubectl" {
  description = "Commande pour configurer kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Informations de déploiement résumées
output "deployment_info" {
  description = "Informations résumées pour Phase 1"
  value = {
    region         = var.aws_region
    environment    = var.environment
    eks_cluster    = module.eks.cluster_name
    vpc_id         = module.vpc.vpc_id
    nodes_deployed = "${var.node_desired_size} worker nodes"
  }
}
