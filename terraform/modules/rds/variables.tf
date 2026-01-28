# ==============================================================================
# RDS Module Variables - InfoLine Project
# ==============================================================================

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS subnet group"
  type        = list(string)
}

variable "eks_security_group_id" {
  description = "Security group ID of the EKS cluster for PostgreSQL access"
  type        = string
}

# ------------------------------------------------------------------------------
# Database Configuration
# ------------------------------------------------------------------------------

variable "database_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "infoline"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "infoline_admin"
  sensitive   = true
}

variable "master_password" {
  description = "Master password for the database (should be passed securely)"
  type        = string
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Instance Configuration
# ------------------------------------------------------------------------------

variable "instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
  
  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "Instance class must be a valid RDS instance type (e.g., db.t3.micro)."
  }
}

# ------------------------------------------------------------------------------
# Storage Configuration
# ------------------------------------------------------------------------------

variable "allocated_storage" {
  description = "Initial allocated storage in GB (Free Tier: 20GB)"
  type        = number
  default     = 20
  
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 100
    error_message = "Allocated storage must be between 20 and 100 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB (0 to disable)"
  type        = number
  default     = 30
}

# ------------------------------------------------------------------------------
# Backup Configuration
# ------------------------------------------------------------------------------

variable "backup_retention_period" {
  description = "Number of days to retain backups (0 to disable, Free Tier: up to 7 days)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

# ------------------------------------------------------------------------------
# Optional Variables
# ------------------------------------------------------------------------------

variable "lambda_security_group_id" {
  description = "Security group ID of Lambda functions (if deployed in VPC)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}