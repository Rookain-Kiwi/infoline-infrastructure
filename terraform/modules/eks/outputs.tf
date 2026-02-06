output "cluster_id" {
  description = "ID du cluster EKS"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint du cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificat CA du cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "ID du security group du cluster"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "ID du security group des nodes"
  value       = aws_security_group.node.id
}

output "cluster_oidc_issuer_url" {
  description = "URL de l'OIDC provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN de l'OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "node_group_id" {
  description = "ID du node group"
  value       = aws_eks_node_group.main.id
}

output "node_role_arn" {
  description = "ARN du rôle IAM des nodes"
  value       = aws_iam_role.node.arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN du rôle IAM pour EBS CSI Driver"
  value       = aws_iam_role.ebs_csi_driver.arn
}
