# ============================================================================
# INFOLINE - Infrastructure as Code - Phase 1
# TP Administrateur Système DevOps
# ============================================================================
# Phase 1: VPC + EKS Cluster uniquement
# Phase 2: Lambda + RDS + ECR (à venir)

# Module VPC - Réseau de base pour toute l'infrastructure
module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  tags = var.tags
}

# Module EKS - Cluster Kubernetes pour l'API Java et les applications
module "eks" {
  source = "./modules/eks"

  project_name        = var.project_name
  environment         = var.environment
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  tags = var.tags

  depends_on = [module.vpc]
}