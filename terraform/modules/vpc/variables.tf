variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block pour le VPC"
  type        = string
}

variable "availability_zones" {
  description = "Liste des availability zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks pour les subnets privés"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks pour les subnets publics"
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks pour les subnets de base de données"
  type        = list(string)
}

variable "tags" {
  description = "Tags additionnels"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "Nom du cluster EKS pour les tags des subnets Kubernetes"
  type        = string
}
