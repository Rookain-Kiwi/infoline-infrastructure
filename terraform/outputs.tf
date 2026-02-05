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

output "configure_kubectl" {
  description = "Commande pour configurer kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

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

# ============================================================================
# Outputs - RDS PostgreSQL
# ============================================================================
output "rds_endpoint" {
  description = "RDS instance connection endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "RDS instance hostname"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "Name of the default database"
  value       = module.rds.db_name
}

output "rds_connection_string" {
  description = "JDBC connection string for Java applications"
  value       = module.rds.db_connection_string
}

output "rds_connection_url" {
  description = "PostgreSQL connection URL"
  value       = module.rds.db_connection_url
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.rds.db_security_group_id
}

# ============================================================================
# Outputs - ECR Backend
# ============================================================================
output "ecr_backend_repository_url" {
  description = "URL du repository ECR backend"
  value       = module.ecr.repository_url
}

output "ecr_backend_repository_name" {
  description = "Nom du repository ECR backend"
  value       = module.ecr.repository_name
}

output "ecr_backend_registry_id" {
  description = "Registry ID du repository ECR"
  value       = module.ecr.registry_id
}

# ============================================================================
# Outputs - ECR Frontend
# ============================================================================
output "ecr_frontend_repository_url" {
  description = "URL du repository ECR frontend"
  value       = module.ecr.frontend_repository_url
}

output "ecr_frontend_repository_name" {
  description = "Nom du repository ECR frontend"
  value       = module.ecr.frontend_repository_name
}
