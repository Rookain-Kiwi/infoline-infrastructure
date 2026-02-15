# ==============================================================================
# InfoLine Infrastructure as Code
# ==============================================================================
# Orchestre le déploiement complet de l'infrastructure InfoLine sur AWS
# région eu-west-3 (Paris) via 5 modules Terraform indépendants.
#
# Stack déployée :
#   - VPC multi-AZ  : réseau 3 tiers sur eu-west-3a/b/c
#   - EKS Cluster   : Kubernetes t3.medium ON_DEMAND pour les applications
#   - RDS PostgreSQL: base de données relationnelle pour l'API backend
#   - ECR            : registres Docker pour les images backend et frontend
#   - Lambda         : fonction d'authentification serverless Node.js
#
# Ordre de déploiement (géré par depends_on et les références inter-modules) :
#   1. VPC (pas de dépendance)
#   2. EKS + RDS + ECR + Lambda (dépendent du VPC)
#   3. Providers kubernetes/helm (configurés après création du cluster EKS)
#
# Pour le cycle destroy/recreate journalier, utiliser les scripts :
#   ./scripts/startup-infra.sh (recreate)
#   ./scripts/shutdown-infra.sh (destroy)
# ==============================================================================

# ------------------------------------------------------------------------------
# Module VPC
# ------------------------------------------------------------------------------
# Premier module déployé — tous les autres dépendent du réseau.
# Crée le VPC, les subnets (public/private/database), les NAT Gateways,
# l'Internet Gateway et les route tables associées.
# cluster_name est passé pour tagger les subnets avec les labels Kubernetes
# requis par l'AWS Load Balancer Controller (kubernetes.io/cluster/<name>).
# ------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project_name          = var.project_name
  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  private_subnet_cidrs  = var.private_subnet_cidrs
  public_subnet_cidrs   = var.public_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  cluster_name          = var.cluster_name  # Pour les tags kubernetes.io/cluster/*

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Module EKS
# ------------------------------------------------------------------------------
# Déploie le cluster Kubernetes et son node group sur les subnets privés.
#
# private_subnet_ids : workers placés en subnets privés (pas d'IP publique)
# public_subnet_ids  : passés pour la configuration vpc_config du cluster
#                      (assure la visibilité des LoadBalancers publics)
#
# depends_on = [module.vpc] : force la création complète du VPC avant EKS,
# notamment la disponibilité des NAT Gateways (les workers en ont besoin
# pour puller les images ECR au démarrage).
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Module RDS PostgreSQL
# ------------------------------------------------------------------------------
# Déploie l'instance PostgreSQL 16 dans les subnets privés du VPC.
# eks_security_group_id : permet au module RDS de créer la règle SG ingress
# autorisant le trafic PostgreSQL (5432) depuis les worker nodes EKS.
#
# Les credentials (master_username, master_password) sont passés depuis
# les variables Terraform — master_password est fourni via TF_VAR_db_password
# ou terraform.tfvars (exclu du versioning Git via .gitignore).
# ------------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment

  # Réseau — outputs du module VPC
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Accès restreint aux worker nodes EKS uniquement
  eks_security_group_id = module.eks.cluster_security_group_id

  # Credentials base de données
  database_name   = var.db_name
  master_username = var.db_username
  master_password = var.db_password

  # Dimensionnement instance (db.t3.micro — Free Tier compatible)
  instance_class = var.db_instance_class

  # Stockage avec autoscaling (20GB initial → 30GB max)
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage

  # Rétention des sauvegardes automatiques
  backup_retention_period = var.db_backup_retention_period

  tags = {
    Component = "Database"
  }
}

# ------------------------------------------------------------------------------
# Module ECR
# ------------------------------------------------------------------------------
# Crée les dépôts Docker pour les images backend (Spring Boot) et frontend
# (Angular). Indépendant des autres modules — peut être déployé en premier
# pour permettre aux pipelines CI/CD de pusher des images avant le cluster EKS.
#
# Les dépôts persistent entre les cycles destroy/recreate (force_delete = true
# dans le module permet la suppression sans erreur lors du destroy).
# ------------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  environment  = var.environment
  project_name = var.project_name
}

# ------------------------------------------------------------------------------
# Module Lambda
# ------------------------------------------------------------------------------
# Déploie la fonction d'authentification serverless Node.js 20.x.
# Indépendant du VPC — Lambda hors VPC pour éviter la latence cold start
# additionnelle liée à la création des ENIs VPC.
#
# La Function URL est provisionnée mais son invocation depuis un navigateur
# est bloquée par les SCP du compte AWS Education. L'invocation CLI
# est alors validée via validate-infra.sh.
# ------------------------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}