variable "aws_region" {
  description = "Région AWS pour déployer l'infrastructure"
  type        = string
  default     = "eu-west-3"  # Paris
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "infoline"
}

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "infoline-eks-cluster"
}

variable "cluster_version" {
  description = "Version de Kubernetes pour EKS"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones pour le VPC"
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks pour les subnets privés"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks pour les subnets publics"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks pour les subnets de base de données"
  type        = list(string)
  default     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

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
}

variable "lambda_runtime" {
  description = "Runtime pour les fonctions Lambda"
  type        = string
  default     = "java17"
}

variable "tags" {
  description = "Tags additionnels pour toutes les ressources"
  type        = map(string)
  default     = {}
}

# RDS Database Configuration

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "infoline"
}

variable "db_username" {
  description = "Master username for PostgreSQL"
  type        = string
  default     = "infoline_admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for PostgreSQL (use environment variable or secrets manager)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance type (Free Tier: db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage in GB (Free Tier: 20GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 30
}

variable "db_backup_retention_period" {
  description = "Number of days to retain backups (Free Tier: up to 7 days)"
  type        = number
  default     = 7
}