# Configuration InfoLine - Optimisé pour Free Tier
project_name = "infoline"
environment  = "dev"

# VPC Configuration
vpc_cidr             = "172.16.0.0/16"
availability_zones   = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]

# Subnets configuration (aligned with 172.16.0.0/16 VPC CIDR)
private_subnet_cidrs  = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
public_subnet_cidrs   = ["172.16.101.0/24", "172.16.102.0/24", "172.16.103.0/24"]
database_subnet_cidrs = ["172.16.201.0/24", "172.16.202.0/24", "172.16.203.0/24"]

# EKS Configuration
cluster_name    = "infoline-eks-cluster"
cluster_version = "1.31"

# EKS Nodes - t3.micro pour Free Tier
node_instance_types = ["t3.micro"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3

# Tags
tags = {
  Project     = "InfoLine"
  Environment = "Dev"
  ManagedBy   = "Terraform"
}