# Configuration InfoLine - Phase 1
aws_region = "eu-west-3"
environment = "dev"
project_name = "infoline"

# EKS Configuration
cluster_name    = "infoline-eks-cluster"
cluster_version = "1.31"

# Node Group - FREE TIER
node_instance_types = ["t3.micro"]
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 2

# Network
vpc_cidr              = "10.0.0.0/16"
availability_zones    = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
private_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
database_subnet_cidrs = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

# Tags
tags = {
  Student = "jenkins-leroy"
  TP      = "DevOps"
}