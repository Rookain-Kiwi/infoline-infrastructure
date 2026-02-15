# ==============================================================================
# RDS PostgreSQL Module - InfoLine Project
# ==============================================================================
# Module pour déployer une instance RDS PostgreSQL optimisée pour le budget
# AWS Free Tier Account :
#   Instance  : db.t3.micro (2 vCPU, 1GB RAM) — inclus dans le Free Tier
#   Storage   : 20GB gp2 — dans les limites Free Tier
#   Multi-AZ  : Désactivé — réplication synchrone non nécessaire en dev,
#               économie supplémentaire sur le coût d'instance
#   Backups   : 7 jours de rétention — fenêtre de restauration point-in-time
#
# La base héberge les données applicatives InfoLine (articles, utilisateurs,
# produits) et est accessible uniquement depuis les subnets privés EKS.
# ==============================================================================

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------
# Définit les subnets dans lesquels RDS peut placer l'instance.
# Utilise les subnets privés (pas les subnets database dédiés) pour permettre
# la communication directe avec les pods EKS sans traverser de NAT.
# Un subnet group avec au moins 2 subnets dans des AZ différentes est requis
# par AWS même si Multi-AZ est désactivé (prérequis de l'API RDS).
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# DB Parameter Group
# ------------------------------------------------------------------------------
# Personnalisation des paramètres PostgreSQL 16.
# family = "postgres16" : doit correspondre exactement à la version majeure.
# postgres16 pour PostgreSQL 16.x
#
# Paramètres activés :
# log_connections    = 1 : trace chaque nouvelle connexion à la base
#                          (utile pour détecter les connection leaks)
# log_disconnections = 1 : trace chaque déconnexion avec la durée de session
#                          (complète log_connections pour l'audit)
#
# Ces logs sont exportés vers CloudWatch via enabled_cloudwatch_logs_exports.
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-${var.environment}-postgres-params"
  family = "postgres16"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres-params"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# RDS PostgreSQL Instance
# ------------------------------------------------------------------------------
resource "aws_db_instance" "main" {

  # --- Identification ---
  identifier = "${var.project_name}-${var.environment}-postgres"

  # --- Moteur ---
  engine         = "postgres"
  engine_version = "16.11"       # Version mineure fixée pour la reproductibilité
  instance_class = var.instance_class  # db.t3.micro par défaut (variables.tf)

  # --- Base de données ---
  db_name  = var.database_name    # Nom du schéma initial créé au provisioning
  username = var.master_username  # sensitive = true dans variables.tf
  password = var.master_password  # sensitive = true, fourni via TF_VAR_*
  port     = 5432                 # Port PostgreSQL standard

  # --- Stockage ---
  # gp2 : SSD généraliste, suffisant pour la charge
  # storage_encrypted = true : chiffrement AES-256 via AWS KMS sans surcoût
  # max_allocated_storage > allocated_storage : active l'autoscaling de storage
  # (déclenchement automatique quand l'espace libre passe sous 10%)
  allocated_storage     = var.allocated_storage      # 20GB initial
  max_allocated_storage = var.max_allocated_storage  # 30GB maximum
  storage_type          = "gp2"
  storage_encrypted     = true

  # --- Réseau ---
  # publicly_accessible = false : l'instance n'a pas d'IP publique,
  # accessible uniquement depuis les subnets privés du VPC via le SG RDS
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # --- Paramètres ---
  parameter_group_name = aws_db_parameter_group.main.name

  # --- Haute disponibilité ---
  # Multi-AZ désactivé : réplication synchrone vers une AZ secondaire non
  # requise en dev. En production, passer à true pour le failover automatique.
  multi_az = false

  # --- Sauvegardes ---
  # backup_window : plage de sauvegarde automatique (heure UTC, faible activité)
  # maintenance_window : plage de maintenance AWS (mises à jour mineures auto)
  # Les deux fenêtres ne doivent pas se chevaucher.
  backup_retention_period = var.backup_retention_period  # 7 jours
  backup_window           = "03:00-04:00"                # 3h-4h UTC
  maintenance_window      = "Mon:04:00-Mon:05:00"        # Lundi 4h-5h UTC

  # --- Lifecycle ---
  # skip_final_snapshot = true : empêche le snapshot lors d'un terraform destroy
  # Indispensable pour le cycle destroy/recreate journalier du projet —
  # les snapshots finaux s'accumulent et consomment du stockage facturé.
  skip_final_snapshot       = true
  final_snapshot_identifier = null

  # deletion_protection = false : permet le destroy sans intervention manuelle
  # En production, il faudrait passer à true et désactiver explicitement avant destroy.
  deletion_protection = false

  # --- Observabilité ---
  # Exporte les logs PostgreSQL et les logs de mise à jour vers CloudWatch Logs.
  # "postgresql" : logs applicatifs (connexions, erreurs, requêtes lentes)
  # "upgrade"    : logs des opérations de mise à jour de version
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # auto_minor_version_upgrade : AWS applique automatiquement les patches
  # de sécurité mineurs (ex: 16.3 → 16.4) pendant la maintenance_window
  auto_minor_version_upgrade = true

  # Propage les tags de l'instance vers les snapshots automatiques et manuels
  copy_tags_to_snapshot = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = "Education"   # Traçabilité budgétaire
  }
}