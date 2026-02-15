# ==============================================================================
# OUTPUTS - Module EKS
# ==============================================================================
# Expose les attributs du cluster EKS pour les modules et ressources
# qui les consomment. Ces outputs sont référencés dans :
#   - provider.tf (configuration des providers kubernetes et helm)
#   - Module RDS (eks_security_group_id pour le Security Group RDS)
#   - Scripts startup/shutdown (cluster_name pour kubectl et aws cli)
#   - GitHub Actions (cluster_endpoint, cluster_name pour kubeconfig)
# ==============================================================================

# ------------------------------------------------------------------------------
# Identifiants du cluster
# ------------------------------------------------------------------------------

# ID interne AWS du cluster — identique au nom pour EKS.
# Utilisé comme référence dans les dépendances Terraform entre les modules.
output "cluster_id" {
  description = "ID du cluster EKS"
  value       = aws_eks_cluster.main.id
}

# Nom du cluster — utilisé dans toutes les commandes kubectl et aws eks :
#   aws eks update-kubeconfig --name <cluster_name>
#   aws eks get-token --cluster-name <cluster_name>
output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = aws_eks_cluster.main.name
}

# ------------------------------------------------------------------------------
# Connexion au cluster
# ------------------------------------------------------------------------------

# URL HTTPS de l'API server Kubernetes.
# Référencée dans provider.tf (host = module.eks.cluster_endpoint)
# et dans les pipelines GitHub Actions pour configurer kubeconfig.
output "cluster_endpoint" {
  description = "Endpoint HTTPS de l'API server EKS"
  value       = aws_eks_cluster.main.endpoint
}

# Certificat de l'autorité de certification du cluster (encodé base64).
# Permet à kubectl et aux providers Terraform de vérifier l'authenticité
# de l'API server.
# sensitive = true : masqué dans les logs terraform plan/apply et dans
# les outputs GitHub Actions pour éviter toute exposition du certificat.
output "cluster_certificate_authority_data" {
  description = "Certificat CA du cluster (base64) — utilisé par kubectl et les providers K8s/Helm"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------

# SG du control plane — référencé dans le module RDS pour autoriser
# l'accès PostgreSQL depuis les pods EKS (via node SG).
output "cluster_security_group_id" {
  description = "ID du security group du control plane EKS"
  value       = aws_security_group.cluster.id
}

# SG des worker nodes — passé au module RDS (var.eks_security_group_id)
# pour la règle ingress PostgreSQL : seuls les nodes EKS atteignent RDS.
output "node_security_group_id" {
  description = "ID du security group des worker nodes EKS"
  value       = aws_security_group.node.id
}

# ------------------------------------------------------------------------------
# IRSA - OIDC Provider
# ------------------------------------------------------------------------------

# URL de l'issuer OIDC du cluster — format :
#   https://oidc.eks.eu-west-3.amazonaws.com/id/<cluster_id>
# Utilisée pour construire les conditions des trust policies IRSA
# (voir module EKS).
output "cluster_oidc_issuer_url" {
  description = "URL de l'issuer OIDC du cluster (pour construction des trust policies IRSA)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ARN du provider OIDC IAM — référencé dans les trust policies IRSA
# de tout rôle IAM destiné à être assumé par un ServiceAccount Kubernetes.
# Format : arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>
output "oidc_provider_arn" {
  description = "ARN du provider OIDC IAM (pour les trust policies IRSA)"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

# ------------------------------------------------------------------------------
# Node Group
# ------------------------------------------------------------------------------

# ID du node group — format : <cluster_name>:<node_group_name>
# Utilisé dans shutdown-infra.sh pour le polling de suppression :
#   aws eks delete-nodegroup --cluster-name ... --nodegroup-name ...
output "node_group_id" {
  description = "ID du node group EKS (format: cluster_name:nodegroup_name)"
  value       = aws_eks_node_group.main.id
}

# ARN du rôle IAM des nodes — peut être référencé pour attacher
# des policies supplémentaires sans modifier le module EKS directement.
output "node_role_arn" {
  description = "ARN du rôle IAM des worker nodes"
  value       = aws_iam_role.node.arn
}

# ------------------------------------------------------------------------------
# EBS CSI Driver
# ------------------------------------------------------------------------------

# ARN du rôle IRSA EBS CSI Driver — passé à Helm lors de l'installation
# dans startup-infra.sh
# Permet au pod CSI controller d'assumer ce rôle pour gérer les volumes EBS.
output "ebs_csi_driver_role_arn" {
  description = "ARN du rôle IRSA pour le pod controller de l'EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}