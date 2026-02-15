# ==============================================================================
# RDS Security Group - InfoLine Project
# ==============================================================================
# Contrôle l'accès réseau à l'instance RDS PostgreSQL.
# Principe du moindre privilège : seul le port 5432 depuis les sources
# autorisées est ouvert en entrée — aucun accès public, aucun autre port.
#
# Séparation des règles en ressources distinctes (aws_security_group_rule)
# plutôt qu'en blocs inline : permet d'ajouter/supprimer des règles
# individuellement sans recréer le security group entier.
# ==============================================================================

# ------------------------------------------------------------------------------
# Security Group RDS
# ------------------------------------------------------------------------------
# name_prefix (avec tiret final) : AWS génère un suffixe unique pour éviter
# les conflits de noms lors du cycle destroy/recreate journalier.
#
# lifecycle.create_before_destroy = true : lors d'un remplacement du SG
# (changement de vpc_id ou name_prefix), le nouveau SG est créé avant que
# l'ancien soit détruit — évite une interruption de connectivité pour RDS.
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
# Règles Ingress
# ------------------------------------------------------------------------------

# Accès PostgreSQL (5432) depuis les worker nodes EKS uniquement.
# source_security_group_id = var.eks_security_group_id : référence le SG des
# nodes EKS — seuls les pods tournant sur ces nodes peuvent atteindre RDS.
# Plus restrictif qu'un CIDR : si un node est supprimé, son accès disparaît
# automatiquement avec lui.
resource "aws_security_group_rule" "rds_ingress_from_eks" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.eks_security_group_id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from EKS cluster"
}

# Accès PostgreSQL depuis Lambda (désactivé).
# Lambda InfoLine est déployée hors VPC (Function URL publique) — elle
# n'a pas besoin d'accès direct à RDS (authentification JWT uniquement,
# pas d'accès direct à la base de données).
# À réactiver si, un jour, Lambda est migrée dans le VPC et nécessite un accès DB.
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
# Règles Egress
# ------------------------------------------------------------------------------

# Trafic sortant entièrement ouvert : RDS peut initier des connexions sortantes
# vers Internet si nécessaire (mises à jour de certificats SSL, NTP, etc.).
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}