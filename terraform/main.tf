# ============================================================================
# INFOLINE - Infrastructure as Code
# TP Administrateur Système DevOps
# ============================================================================
# Infrastructure complète déployée :
# - VPC multi-AZ (eu-west-3a, eu-west-3b, eu-west-3c)
# - EKS Cluster (t3.medium, ON_DEMAND)
# - RDS PostgreSQL 16
# - ECR (backend + frontend)
# - Lambda (authentification)
# ============================================================================

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

# Module RDS PostgreSQL
module "rds" {
  source = "./modules/rds"
  
  # Project identification
  project_name = var.project_name
  environment  = var.environment
  
  # Network configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  # Security: Allow access from EKS
  eks_security_group_id = module.eks.cluster_security_group_id
  
  # Database configuration
  database_name   = var.db_name
  master_username = var.db_username
  master_password = var.db_password
  
  # Instance configuration (Free Tier)
  instance_class = var.db_instance_class
  
  # Storage configuration (Free Tier)
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  
  # Backup configuration
  backup_retention_period = var.db_backup_retention_period
  
  # Tags supplémentaires
  tags = {
    Component = "Database"
  }
}

# Module ECR pour les images Docker
module "ecr" {
  source = "./modules/ecr"
  
  environment  = var.environment
  project_name = var.project_name
}
# Module Lambda - Service d'authentification serverless
module "lambda" {
  source = "./modules/lambda"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}
