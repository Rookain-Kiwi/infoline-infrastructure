# ==============================================================================
# RDS Module Outputs - InfoLine Project
# ==============================================================================
# Outputs pour permettre aux autres modules/applications d'accéder à RDS
# ==============================================================================

# ------------------------------------------------------------------------------
# Connection Information
# ------------------------------------------------------------------------------

output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Name of the default database"
  value       = aws_db_instance.main.db_name
}

output "db_master_username" {
  description = "Master username for database access"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Network Information
# ------------------------------------------------------------------------------

output "db_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

# ------------------------------------------------------------------------------
# Configuration Information
# ------------------------------------------------------------------------------

output "db_instance_class" {
  description = "RDS instance class"
  value       = aws_db_instance.main.instance_class
}

output "db_allocated_storage" {
  description = "Allocated storage in GB"
  value       = aws_db_instance.main.allocated_storage
}

output "db_engine_version" {
  description = "PostgreSQL engine version"
  value       = aws_db_instance.main.engine_version
}

# ------------------------------------------------------------------------------
# Connection String (for convenience)
# ------------------------------------------------------------------------------

output "db_connection_string" {
  description = "Full JDBC connection string"
  value       = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = false
}

output "db_connection_url" {
  description = "PostgreSQL connection URL (without credentials)"
  value       = "postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  sensitive   = false
}