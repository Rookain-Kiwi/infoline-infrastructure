# ==============================================================================
# RDS PostgreSQL Module - InfoLine Project
# ==============================================================================
# Module pour déployer une instance RDS PostgreSQL optimisée Free Tier
# Instance: db.t3.micro (750h/mois gratuit)
# Storage: 20GB gp2 (dans Free Tier)
# Multi-AZ: Désactivé (économie de coûts)
# ==============================================================================

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------
# Groupe de sous-réseaux pour RDS (requis pour déploiement multi-subnet)
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
# Configuration PostgreSQL personnalisée si nécessaire
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
  # Identification
  identifier = "${var.project_name}-${var.environment}-postgres"

  # Engine configuration
  engine               = "postgres"
  engine_version       = "16.11"
  instance_class       = var.instance_class
  
  # Database configuration
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  port     = 5432

  # Storage configuration (Free Tier)
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # High Availability (désactivé pour Free Tier)
  multi_az = false

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"
  
  # Pour projet académique: pas de snapshot final lors du destroy
  skip_final_snapshot       = true
  final_snapshot_identifier = null
  
  # Deletion protection désactivée (pour cycle destroy/apply journalier)
  deletion_protection = false

  # Performance Insights (gratuit pour db.t3.micro)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Copy tags to snapshots
  copy_tags_to_snapshot = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = "Education"
  }
}