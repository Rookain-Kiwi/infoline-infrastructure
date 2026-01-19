variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement de déploiement"
  type        = string
}

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Version de Kubernetes"
  type        = string
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs des subnets privés pour les worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "IDs des subnets publics pour les load balancers"
  type        = list(string)
}

variable "node_instance_types" {
  description = "Types d'instances pour les worker nodes"
  type        = list(string)
}

variable "node_desired_size" {
  description = "Nombre désiré de worker nodes"
  type        = number
}

variable "node_min_size" {
  description = "Nombre minimum de worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Nombre maximum de worker nodes"
  type        = number
}

variable "tags" {
  description = "Tags additionnels"
  type        = map(string)
  default     = {}
}