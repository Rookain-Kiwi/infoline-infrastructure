# =============================================================================
# MODULE EKS - InfoLine Infrastructure
# =============================================================================
# Déploie le cluster Kubernetes managé (EKS) et tous ses composants :
#   - IAM roles/policies pour le control plane et les worker nodes
#   - Security groups pour les communications cluster ↔ nodes ↔ pods
#   - Node group ON_DEMAND t3.medium (2 vCPU, 4GB RAM)
#   - OIDC Provider pour IRSA (IAM Roles for Service Accounts)
#   - EBS CSI Driver (via Helm) pour les volumes persistants (Elasticsearch)
#   - Add-ons EKS managés : CoreDNS, kube-proxy, vpc-cni
# =============================================================================

# =============================================================================
# IAM - CONTROL PLANE (Cluster EKS)
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role du Cluster EKS
# -----------------------------------------------------------------------------
# Le control plane EKS assume ce rôle pour gérer les ressources AWS en son nom :
# création d'ENIs, gestion des LoadBalancers, accès aux logs CloudWatch, etc.
# Trust policy : seul le service eks.amazonaws.com peut assumer ce rôle.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-role"
    }
  )
}

# AmazonEKSClusterPolicy : permissions de base du control plane EKS
# (gestion des ENIs, security groups, describe EC2, etc.)
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# AmazonEKSVPCResourceController : permet au control plane de gérer
# les interfaces réseau des pods (nécessaire pour le VPC CNI plugin)
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# =============================================================================
# SECURITY GROUPS - CONTROL PLANE
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group du Cluster (control plane)
# -----------------------------------------------------------------------------
# Protège l'API server EKS. La règle egress ouverte permet au control plane
# de contacter les worker nodes sur tous les ports nécessaires (kubelet, etc.).
# -----------------------------------------------------------------------------
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
    }
  )
}

# Port 443 ouvert vers 0.0.0.0/0 : permet l'accès à l'API server depuis
# les pipelines GitHub Actions, kubectl local et les worker nodes.
# endpoint_public_access = true dans le cluster autorise cet accès externe.
resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# =============================================================================
# CLUSTER EKS
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster EKS Principal
# -----------------------------------------------------------------------------
# endpoint_private_access = true  : les workers (subnets privés) atteignent
#                                   l'API server sans passer par Internet
# endpoint_public_access  = true  : kubectl depuis GitHub Actions / poste local
#
# Les subnet_ids combinent privés + publics : EKS place le control plane ENIs
# dans les subnets privés mais a besoin de visibilité sur les publics pour
# les LoadBalancers.
#
# enabled_cluster_log_types : tous les logs activés → CloudWatch Logs pour
# audit de sécurité et troubleshooting (api, audit, authenticator,
# controllerManager, scheduler).
# -----------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )

  # Le cluster ne peut être créé qu'une fois les policies IAM attachées.
  # Sans ces dépendances explicites, Terraform pourrait tenter de créer
  # le cluster avant que le rôle IAM soit complètement configuré.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

# =============================================================================
# IAM - WORKER NODES
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role des Worker Nodes
# -----------------------------------------------------------------------------
# Les instances EC2 (worker nodes) assument ce rôle pour s'enregistrer auprès
# du cluster et accéder aux services AWS (ECR pour les images, CloudWatch
# pour les logs, VPC CNI pour la gestion des ENIs des pods).
# Trust policy : seul le service ec2.amazonaws.com peut assumer ce rôle.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-role"
    }
  )
}

# AmazonEKSWorkerNodePolicy : permet aux nodes de s'enregistrer au cluster
# et de recevoir les instructions du control plane (describe, list ressources)
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# AmazonEKS_CNI_Policy : permet au VPC CNI plugin de gérer les ENIs secondaires
# pour assigner des IPs VPC directement aux pods
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# AmazonEC2ContainerRegistryReadOnly : accès en lecture à ECR pour puller
# les images Docker du backend et frontend InfoLine
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# CloudWatchAgentServerPolicy : permet aux nodes d'envoyer des métriques
# et logs système vers CloudWatch (complément à la stack ELK)
resource "aws_iam_role_policy_attachment" "node_CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node.name
}

# =============================================================================
# SECURITY GROUPS - WORKER NODES
# =============================================================================

# -----------------------------------------------------------------------------
# Security Group des Worker Nodes
# -----------------------------------------------------------------------------
# Tag kubernetes.io/cluster = "owned" : indique à EKS que ce SG appartient
# exclusivement à ce cluster (vs "shared" pour les subnets VPC).
# -----------------------------------------------------------------------------
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.cluster_name}-node-sg"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

# Communication inter-nodes (tous ports) : nécessaire pour les appels
# entre pods sur des nodes différents (ex: backend → Elasticsearch)
resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
}

# Ports 1025-65535 depuis le control plane : permet au control plane d'appeler
# le kubelet (port 10250) et les NodePorts pour les health checks et webhooks
resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

# Port 443 depuis les nodes vers le control plane : permet aux pods d'appeler
# l'API server Kubernetes (nécessaire pour les ServiceAccounts, IRSA, etc.)
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# =============================================================================
# NODE GROUP
# =============================================================================

# -----------------------------------------------------------------------------
# Node Group Principal (ON_DEMAND)
# -----------------------------------------------------------------------------
# t3.medium (2 vCPU, 4GB RAM) : taille minimale viable pour ce projet.
#   - t3.micro (1GB) : insuffisant, Elasticsearch seul consomme ~512MB JVM heap
#   - t3.small (2GB) : trop juste avec ELK + backend + frontend simultanés
#
# SPOT testé mais abandonné pour deux raisons :
#   1. Indisponibilité de capacité SPOT en eu-west-3 (compte Education limité)
#   2. Restrictions SCP du compte AWS Academy bloquant SPOT sur EKS
# ON_DEMAND garantit la disponibilité continue des nodes en dev.
#
# max_unavailable = 1 : lors d'une mise à jour du node group, au plus 1 node
# est indisponible simultanément (rolling update sans interruption de service).
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-node-group"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# =============================================================================
# IRSA - IAM ROLES FOR SERVICE ACCOUNTS
# =============================================================================

# -----------------------------------------------------------------------------
# OIDC Provider
# -----------------------------------------------------------------------------
# IRSA permet à des pods Kubernetes d'assumer des rôles IAM AWS sans stocker
# de credentials statiques. Mécanisme :
#   Pod → ServiceAccount annoté → OIDC token → AssumeRoleWithWebIdentity → AWS
#
# Le thumbprint TLS est extrait dynamiquement du certificat de l'issuer OIDC
# du cluster (endpoint HTTPS d'EKS). Il authentifie l'identité du provider
# auprès d'AWS IAM.
# -----------------------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}

# =============================================================================
# EBS CSI DRIVER - IAM
# =============================================================================
# L'EBS CSI Driver gère les volumes persistants Kubernetes sur EBS AWS.
# Utilisé pour le PersistentVolumeClaim d'Elasticsearch (stockage des index).
# Installé via Helm (voir startup-infra.sh) car l'add-on EKS managé
# provoquait systématiquement des timeouts lors du terraform apply.

# -----------------------------------------------------------------------------
# Policy IAM EBS CSI Driver
# -----------------------------------------------------------------------------
# Permissions granulaires pour la gestion du cycle de vie des volumes EBS :
# - Describe* : lecture de l'état des volumes/snapshots/instances
# - CreateVolume/DeleteVolume : provisioning dynamique des PVCs
# - AttachVolume/DetachVolume : montage/démontage sur les nodes
# - CreateSnapshot/DeleteSnapshot : snapshots pour les backups
# - CreateTags/DeleteTags : tagging des ressources créées par le driver
#
# Les conditions sur CreateVolume et DeleteVolume limitent les permissions
# aux seuls volumes créés par le CSI driver (tags ebs.csi.aws.com/cluster
# et CSIVolumeName), évitant tout accès aux volumes non-CSI.
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications"
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateVolume", "CreateSnapshot"]
    }
  }

  statement {
    actions = ["ec2:DeleteTags"]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
  }

  statement {
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/created-for/pvc/name"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Role EBS CSI Driver (IRSA)
# -----------------------------------------------------------------------------
# Trust policy restreinte à un ServiceAccount précis via IRSA :
#   - sub = system:serviceaccount:kube-system:ebs-csi-controller-sa
#     → Seul ce ServiceAccount K8s peut assumer ce rôle
#   - aud = sts.amazonaws.com
#     → Token OIDC destiné à AWS STS uniquement
#
# replace(..., "https://", "") : extrait le hostname de l'issuer OIDC
# pour construire les clés de condition IAM (format sans https://)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.cluster.arn
      }
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ebs-csi-driver-role"
    }
  )
}

resource "aws_iam_role_policy" "ebs_csi_driver" {
  name   = "${var.cluster_name}-ebs-csi-driver-policy"
  role   = aws_iam_role.ebs_csi_driver.id
  policy = data.aws_iam_policy_document.ebs_csi_driver.json
}

# =============================================================================
# ADD-ONS EKS MANAGÉS
# =============================================================================
# Les add-ons EKS managés sont installés et mis à jour par AWS.
# Tous dépendent du node group : les pods d'add-on tournent sur les workers.

# EBS CSI Driver désactivé ici — installé via Helm dans startup-infra.sh.
# L'add-on EKS managé provoquait des timeouts systématiques lors du apply
# (attente infinie de readiness avant que les nodes soient prêts).
# resource "aws_eks_addon" "ebs_csi_driver" {
#   cluster_name = aws_eks_cluster.main.name
#   addon_name   = "aws-ebs-csi-driver"
#   depends_on   = [aws_eks_node_group.main]
# }

# CoreDNS : résolution DNS interne du cluster (service discovery entre pods)
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.main]
}

# kube-proxy : gestion des règles iptables/ipvs pour le routage des Services K8s
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_node_group.main]
}

# vpc-cni : plugin réseau AWS qui assigne des IPs VPC directement aux pods
# (chaque pod reçoit une IP du subnet privé, pas une IP overlay)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  depends_on   = [aws_eks_node_group.main]
}