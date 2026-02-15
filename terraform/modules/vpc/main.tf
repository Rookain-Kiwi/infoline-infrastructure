# =============================================================================
# MODULE VPC - InfoLine Infrastructure
# =============================================================================
# Crée le réseau complet pour héberger l'infrastructure InfoLine sur AWS.
# Architecture 3 tiers répartie sur 3 Availability Zones (eu-west-3a/b/c) :
#
#   Internet
#      │
#   [IGW] ──── Subnets Publics (10.0.101-103.0/24)
#      │         LoadBalancers K8s, NAT Gateways
#      │
#   [NAT] ──── Subnets Privés (10.0.1-3.0/24)
#                Worker nodes EKS (backend, frontend, ELK)
#                      │
#              Subnets Database (10.0.201-203.0/24)
#                RDS PostgreSQL (pas de route vers Internet)
#
# Une NAT Gateway par AZ garantit la haute disponibilité : si une AZ tombe,
# les workers de cette AZ continuent d'accéder à Internet via leur NAT local.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Principal
# -----------------------------------------------------------------------------
# enable_dns_hostnames + enable_dns_support sont obligatoires pour EKS :
# les worker nodes doivent résoudre les endpoints AWS (ECR, S3, API server).
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
# Point d'entrée/sortie unique vers Internet pour les subnets publics.
# Nécessaire pour les LoadBalancers Kubernetes et
# comme point de sortie pour les NAT Gateways.
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# -----------------------------------------------------------------------------
# Elastic IPs pour NAT Gateways
# -----------------------------------------------------------------------------
# Une EIP par AZ = une IP publique fixe par NAT Gateway.
# count = length(var.availability_zones) = 3 EIPs créées (une par AZ).
# depends_on sur l'IGW : AWS exige que l'IGW soit attaché au VPC avant
# d'allouer des EIPs dans ce VPC.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-eip-${var.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Subnets Publics
# -----------------------------------------------------------------------------
# map_public_ip_on_launch = true : toute instance lancée ici reçoit une IP
# publique automatiquement (utile pour les NAT Gateways).
#
# Tags Kubernetes obligatoires :
#   kubernetes.io/role/elb = "1"
#     → Indique à l'AWS Load Balancer Controller que ce subnet peut accueillir
#       des LoadBalancers publics
#   kubernetes.io/cluster/${var.cluster_name}= "shared"
#     → Permet à EKS de découvrir et utiliser ce subnet
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# -----------------------------------------------------------------------------
# Subnets Privés (worker nodes EKS)
# -----------------------------------------------------------------------------
# Pas de map_public_ip_on_launch : les workers n'ont pas d'IP publique.
# Leur accès sortant vers Internet (ECR, S3, API AWS) passe par la NAT Gateway
# de la même AZ, garantissant l'isolation et la sécurité.
#
# Tags Kubernetes obligatoires :
#   kubernetes.io/role/internal-elb = "1"
#     → Permet la création de LoadBalancers internes
#   kubernetes.io/cluster/${var.cluster_name} = "shared"
#     → Découverte des subnets par EKS pour le scheduling des pods
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# -----------------------------------------------------------------------------
# Subnets Database
# -----------------------------------------------------------------------------
# Tier le plus isolé : aucune route vers Internet (ni directe ni via NAT).
# Accessibles uniquement depuis les subnets privés via le security group RDS.
# Répartis sur 3 AZ pour le subnet group RDS (requis pour Multi-AZ).
# -----------------------------------------------------------------------------
resource "aws_subnet" "database" {
  count             = length(var.database_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-${var.availability_zones[count.index]}"
    }
  )
}

# -----------------------------------------------------------------------------
# NAT Gateways
# -----------------------------------------------------------------------------
# Une NAT Gateway par AZ (count = 3) pour la haute disponibilité.
# Chaque NAT est placée dans le subnet public de son AZ et utilise son EIP.
# Les workers privés de l'AZ X routent leur trafic sortant via la NAT de l'AZ X.
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-${var.availability_zones[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Table Publique
# -----------------------------------------------------------------------------
# Une seule route table partagée par tous les subnets publics.
# Route par défaut (0.0.0.0/0) → IGW : tout le trafic non local sort vers Internet.
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

# -----------------------------------------------------------------------------
# Route Tables Privées
# -----------------------------------------------------------------------------
# Une route table par AZ (count = 3) pour l'isolation des flux par AZ.
# Chaque route table pointe vers la NAT Gateway de sa propre AZ.
# Si on utilisait une seule route table avec une seule NAT, la panne d'une AZ
# couperait l'accès Internet des workers des autres AZ.
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt-${var.availability_zones[count.index]}"
    }
  )
}

# -----------------------------------------------------------------------------
# Route Table Database
# -----------------------------------------------------------------------------
# Aucune route vers Internet : les subnets database sont strictement isolés.
# Le trafic reste confiné au VPC (communication avec les workers uniquement).
# -----------------------------------------------------------------------------
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-rt"
    }
  )
}

# -----------------------------------------------------------------------------
# Associations Route Tables <-> Subnets
# -----------------------------------------------------------------------------
# Chaque subnet doit être explicitement associé à sa route table.
# Sans association, le subnet utilise la route table principale du VPC.

# Subnets publics → route table publique (IGW)
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Subnets privés → route table privée de la même AZ (NAT Gateway locale)
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Subnets database → route table isolée (pas de route Internet)
resource "aws_route_table_association" "database" {
  count          = length(var.database_subnet_cidrs)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# -----------------------------------------------------------------------------
# Security Group par défaut du VPC
# -----------------------------------------------------------------------------
# AWS crée automatiquement un security group "default" par VPC.
# On le redéfinit explicitement pour le contrôler et éviter les dérives de config.
#
# Règle ingress "self" : autorise uniquement le trafic interne entre ressources
# appartenant à ce même security group.
# Règle egress 0.0.0.0/0 : tout le trafic sortant est autorisé.
# -----------------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol  = -1      # Tous les protocoles
    self      = true    # Uniquement depuis des ressources avec ce même SG
    from_port = 0
    to_port   = 0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"           # Tous les protocoles
    cidr_blocks = ["0.0.0.0/0"] # Tout Internet
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-default-sg"
    }
  )
}