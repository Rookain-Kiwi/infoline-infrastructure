# ==============================================================================
# RDS Security Group - InfoLine Project
# ==============================================================================
# Security Group pour contrôler l'accès à l'instance RDS PostgreSQL
# ==============================================================================

# ------------------------------------------------------------------------------
# RDS Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# Ingress Rules
# ------------------------------------------------------------------------------

# Règle 1: Autoriser le trafic PostgreSQL depuis le cluster EKS
resource "aws_security_group_rule" "rds_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.eks_security_group_id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from EKS cluster"
}

# Règle 2: Autoriser le trafic PostgreSQL depuis Lambda (optionnel)
# Décommenter si Lambda est dans un VPC
# resource "aws_security_group_rule" "rds_ingress_from_lambda" {
#   type                     = "ingress"
#   from_port                = 5432
#   to_port                  = 5432
#   protocol                 = "tcp"
#   source_security_group_id = var.lambda_security_group_id
#   security_group_id        = aws_security_group.rds.id
#   description              = "Allow PostgreSQL access from Lambda functions"
# }

# ------------------------------------------------------------------------------
# Egress Rules
# ------------------------------------------------------------------------------

# Règle de sortie: Autoriser tout le trafic sortant (requis pour updates, etc.)
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}