# =============================================================================
# VARIABLES - InfoLine Infrastructure
# =============================================================================
# Centralise tous les paramètres configurables de l'infrastructure.
# Les valeurs par défaut correspondent à l'environnement de développement.
# Pour surcharger, utiliser un fichier terraform.tfvars (non versionné,
# voir .gitignore) ou des variables d'environnement TF_VAR_*.
# =============================================================================

# -----------------------------------------------------------------------------
# Paramètres généraux
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "Région AWS pour déployer l'infrastructure"
  type        = string
  default     = "eu-west-3"  # Paris - proximité géographique Europe
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "dev"
  # Valeurs attendues : dev / staging / prod
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "infoline"
  # Utilisé comme préfixe dans les noms de ressources AWS
}

# -----------------------------------------------------------------------------
# Cluster EKS
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "infoline-eks-cluster"
}

variable "cluster_version" {
  description = "Version de Kubernetes pour EKS"
  type        = string
  default     = "1.31"
  # Vérifier la compatibilité des add-ons (EBS CSI driver, CoreDNS, kube-proxy)
  # avant toute mise à jour de version
}

# -----------------------------------------------------------------------------
# Réseau VPC
# -----------------------------------------------------------------------------
# Architecture 3 tiers : public / private / database
# Chaque tier est réparti sur 3 AZ pour la haute disponibilité.
# Plan d'adressage :
#   Public   : 10.0.101-103.0/24  (LoadBalancers, NAT Gateways)
#   Private  : 10.0.1-3.0/24     (Worker nodes EKS)
#   Database : 10.0.201-203.0/24  (RDS PostgreSQL)
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16"  # 65 536 adresses disponibles
}

variable "availability_zones" {
  description = "Availability zones pour le VPC"
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  # 3 AZ = résilience maximale en région Paris
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks pour les subnets privés"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  # Worker nodes EKS — pas d'accès direct depuis Internet
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks pour les subnets publics"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  # LoadBalancers Kubernetes (type: LoadBalancer) et NAT Gateways
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks pour les subnets de base de données"
  type        = list(string)
  default     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  # RDS PostgreSQL — isolés, accessibles uniquement depuis les subnets privés
}

# -----------------------------------------------------------------------------
# Worker Nodes EKS
# -----------------------------------------------------------------------------
# t3.medium (2 vCPU, 4GB RAM) est le minimum viable pour ce projet :
#   - t3.micro (1GB) : insuffisant pour Elasticsearch
#   - t3.small (2GB) : limite atteinte rapidement avec ELK + backend + frontend
#   - t3.medium (4GB) : permet de faire tourner tous les pods confortablement
# Node group ON_DEMAND (pas SPOT) pour éviter les interruptions en dev.
# -----------------------------------------------------------------------------

variable "node_instance_types" {
  description = "Types d'instances pour les worker nodes EKS"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Nombre désiré de worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Nombre minimum de worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Nombre maximum de worker nodes"
  type        = number
  default     = 4
  # Limite haute pour l'autoscaling — à ajuster selon le budget disponible
}

# -----------------------------------------------------------------------------
# Tags additionnels
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags additionnels pour toutes les ressources"
  type        = map(string)
  default     = {}
  # Fusionnés avec les default_tags du provider AWS (voir provider.tf)
}

# -----------------------------------------------------------------------------
# Base de données RDS PostgreSQL
# -----------------------------------------------------------------------------

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "infoline"
}

variable "db_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "infoline_admin"
  sensitive   = true  # Masqué dans les logs terraform plan/apply
}

variable "db_password" {
  description = "Master password for PostgreSQL (use environment variable or secrets manager)"
  type        = string
  sensitive   = true
  # Pas de default : doit être fourni via TF_VAR_db_password ou terraform.tfvars
  # terraform.tfvars est exclu du versioning Git (voir .gitignore)
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
  # db.t3.micro = 2 vCPU, 1GB RAM — suffisant pour le volume de données
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20  # Minimum RDS PostgreSQL
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 30
  # Storage autoscaling déclenché quand l'espace libre passe sous 10%
}

variable "db_backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  # 7 jours = fenêtre de restauration suffisante
}