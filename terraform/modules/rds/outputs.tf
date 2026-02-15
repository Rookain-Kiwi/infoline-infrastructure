# ==============================================================================
# OUTPUTS - Module RDS
# ==============================================================================
# Expose les attributs de l'instance PostgreSQL pour ceux qui les consomment :
#   - Backend Spring Boot (db_connection_string, db_master_username via secret)
#   - Module EKS (db_security_group_id pour les règles SG inter-modules)
#   - Scripts de validation (db_instance_endpoint pour les health checks)
#   - GitHub Actions (db_instance_address pour les variables d'environnement)
# ==============================================================================

# ------------------------------------------------------------------------------
# Identification de l'instance
# ------------------------------------------------------------------------------

# Identifiant RDS court — utilisé dans les commandes AWS CLI
output "db_instance_id" {
  description = "Identifiant de l'instance RDS"
  value       = aws_db_instance.main.id
}

# ARN complet — référencé pour les politiques IAM, les alertes CloudWatch
# et les tags de ressource cross-module.
output "db_instance_arn" {
  description = "ARN de l'instance RDS"
  value       = aws_db_instance.main.arn
}

# ------------------------------------------------------------------------------
# Informations de connexion
# ------------------------------------------------------------------------------

# Endpoint complet
# Utilisé directement dans les variables d'environnement du backend
# et dans db_connection_string plus loin.
output "db_instance_endpoint" {
  description = "Endpoint de connexion RDS (host:port)"
  value       = aws_db_instance.main.endpoint
}

# Hostname seul (sans le port) — utile quand l'application gère
# host et port séparément.
output "db_instance_address" {
  description = "Hostname de l'instance RDS (sans port)"
  value       = aws_db_instance.main.address
}

# Port PostgreSQL — 5432 par défaut, exposé séparément pour les
# configurations qui distinguent host / port / dbname.
output "db_instance_port" {
  description = "Port de connexion PostgreSQL"
  value       = aws_db_instance.main.port
}

# Nom du schéma/base créé au provisioning de l'instance.
# Correspond à var.database_name — exporté pour éviter le couplage
# entre modules (le consommateur ne doit pas connaître la variable).
output "db_name" {
  description = "Nom de la base de données PostgreSQL"
  value       = aws_db_instance.main.db_name
}

# Username du compte administrateur RDS.
# sensitive = true : masqué dans les logs terraform output et GitHub Actions.
# À injecter dans les secrets Kubernetes (Secret K8s) plutôt qu'en clair
# dans les ConfigMaps ou variables d'environnement.
output "db_master_username" {
  description = "Username administrateur PostgreSQL"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Réseau
# ------------------------------------------------------------------------------

# ID du SG RDS — référencé pour ajouter des règles d'accès supplémentaires
# depuis d'autres modules sans modifier le module RDS directement.
output "db_security_group_id" {
  description = "ID du security group RDS"
  value       = aws_security_group.rds.id
}

# Nom du subnet group — utile pour les opérations de restauration RDS
output "db_subnet_group_name" {
  description = "Nom du DB subnet group RDS"
  value       = aws_db_subnet_group.main.name
}

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# Classe d'instance effective — permet de vérifier après apply que
# l'instance déployée correspond bien à la configuration attendue
# (db.t3.micro en dev, penser à upgrader si charge insuffisante).
output "db_instance_class" {
  description = "Classe d'instance RDS (ex: db.t3.micro)"
  value       = aws_db_instance.main.instance_class
}

# Stockage alloué en GB — à surveiller : si la base approche de
# max_allocated_storage, l'autoscaling RDS étend le volume automatiquement.
output "db_allocated_storage" {
  description = "Stockage alloué en GB"
  value       = aws_db_instance.main.allocated_storage
}

# Version mineure effective de PostgreSQL après déploiement.
# Peut différer de engine_version dans variables.tf si auto_minor_version_upgrade
# a appliqué un patch pendant la fenêtre de maintenance.
output "db_engine_version" {
  description = "Version PostgreSQL effective après déploiement"
  value       = aws_db_instance.main.engine_version
}

# ------------------------------------------------------------------------------
# Chaînes de connexion
# ------------------------------------------------------------------------------

# JDBC connection string pour Spring Boot (sans credentials).
# sensitive = false : l'URL seule sans credentials n'est pas sensible.
output "db_connection_string" {
  description = "JDBC connection string Spring Boot (sans credentials)"
  value       = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = false
}

# URL PostgreSQL standard
# Utilisée pour les connexions directes depuis les outils d'administration
# et les scripts de validation.
output "db_connection_url" {
  description = "URL de connexion PostgreSQL standard (sans credentials)"
  value       = "postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  sensitive   = false
}