# ==============================================================================
# OUTPUTS - Module VPC
# ==============================================================================
# Expose les identifiants réseau pour les modules qui les consomment :
#   - Module EKS  (vpc_id, private_subnet_ids, public_subnet_ids)
#   - Module RDS  (vpc_id, private_subnet_ids)
#   - Module Lambda (vpc_id si migration dans le VPC nécessaire)
#   - Scripts de validation (nat_gateway_ids, internet_gateway_id)
# ==============================================================================

# Identifiant du VPC — référencé dans tous les modules qui créent des
# ressources réseau (security groups, subnet groups, endpoints, etc.).
output "vpc_id" {
  description = "ID du VPC principal InfoLine"
  value       = aws_vpc.main.id
}

# Plage d'adresses IP du VPC (10.0.0.0/16).
# Utile pour construire des règles CIDR dans les security groups
# permettant la communication intra-VPC sans exposer les IDs de subnets.
output "vpc_cidr" {
  description = "CIDR block du VPC (10.0.0.0/16)"
  value       = aws_vpc.main.cidr_block
}

# ------------------------------------------------------------------------------
# Subnets
# ------------------------------------------------------------------------------

# Liste des 3 IDs de subnets publics (un par AZ : 3a, 3b, 3c).
# Passés au module EKS pour vpc_config et utilisés par les NAT Gateways
# (placées dans les subnets publics).
output "public_subnet_ids" {
  description = "IDs des 3 subnets publics (LoadBalancers, NAT Gateways)"
  value       = aws_subnet.public[*].id
}

# Liste des 3 IDs de subnets privés (un par AZ : 3a, 3b, 3c).
# Utilisés par :
#   - Module EKS  : subnet_ids du node group (workers sans IP publique)
#   - Module RDS  : subnet_ids du DB subnet group
output "private_subnet_ids" {
  description = "IDs des 3 subnets privés (worker nodes EKS, RDS)"
  value       = aws_subnet.private[*].id
}

# Liste des 3 IDs de subnets database (un par AZ : 3a, 3b, 3c).
# C'est le tier le plus isolé — aucune route Internet, accessibles uniquement
# depuis les subnets privés via le security group RDS.
output "database_subnet_ids" {
  description = "IDs des 3 subnets database (tier isolé, pas de route Internet)"
  value       = aws_subnet.database[*].id
}

# ------------------------------------------------------------------------------
# Passerelles réseau
# ------------------------------------------------------------------------------

# Liste des 3 IDs de NAT Gateways (une par AZ).
# Référencés dans shutdown-infra.sh — les NAT Gateways sont les
# ressources les plus longues à supprimer lors du terraform destroy
# Leur suppression libère aussi les EIPs associées.
output "nat_gateway_ids" {
  description = "IDs des 3 NAT Gateways (une par AZ pour HA)"
  value       = aws_nat_gateway.main[*].id
}

# ID de l'Internet Gateway — point d'entrée/sortie unique vers Internet.
# Utilisé dans les scripts de validation pour vérifier que l'IGW
# est bien attaché au VPC avant de tester la connectivité externe.
output "internet_gateway_id" {
  description = "ID de l'Internet Gateway (accès Internet des subnets publics)"
  value       = aws_internet_gateway.main.id
}

# ------------------------------------------------------------------------------
# Security Group
# ------------------------------------------------------------------------------

# ID du SG par défaut du VPC — redéfini explicitement dans main.tf pour
# contrôler ses règles (ingress self uniquement, egress ouvert).
# Exporté pour référence dans les audits de sécurité et les modules
# qui vérifient l'absence de règles trop permissives sur ce SG.
output "default_security_group_id" {
  description = "ID du security group par défaut du VPC (ingress self uniquement)"
  value       = aws_default_security_group.default.id
}