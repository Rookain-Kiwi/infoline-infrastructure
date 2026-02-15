# =============================================================================
# PROVIDER CONFIGURATION - InfoLine Infrastructure
# =============================================================================
# Définit les providers Terraform nécessaires et leurs contraintes de version.
# Trois providers sont utilisés :
#   - aws       : gestion de toutes les ressources AWS (EKS, RDS, Lambda, ECR...)
#   - kubernetes: déploiement des manifests K8s après création du cluster EKS
#   - helm      : installation des charts Helm (EBS CSI driver, ELK stack...)
# =============================================================================

terraform {
  # Version minimale de Terraform requise
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # Accepte 5.x mais pas 6.0
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider AWS
# -----------------------------------------------------------------------------
# La région est paramétrée via var.aws_region (définie dans variables.tf).
# Les default_tags sont automatiquement appliqués à toutes les ressources AWS
# créées par ce Terraform, garantissant une traçabilité et une gestion des
# coûts cohérentes sans devoir répéter les tags dans chaque ressource.
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "InfoLine"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "jenkins-leroy"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Kubernetes
# -----------------------------------------------------------------------------
# Configuré dynamiquement avec les outputs du module EKS après sa création.
# try(..., "") évite les erreurs lors du premier terraform plan/apply, quand
# le cluster n'existe pas encore et que les outputs sont vides.
#
# L'authentification utilise le plugin aws eks get-token (client.authentication
# k8s.io/v1beta1), qui génère un token temporaire via les credentials AWS CLI
# configurés sur la machine. Cela évite de stocker des credentials K8s statiques.
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(module.eks.cluster_name, ""),
      "--region",
      var.aws_region
    ]
  }
}

# -----------------------------------------------------------------------------
# Provider Helm
# -----------------------------------------------------------------------------
# Utilise la même configuration d'authentification que le provider Kubernetes.
# Le bloc kubernetes imbriqué dans helm est requis car Helm doit communiquer
# avec l'API server du cluster pour installer/mettre à jour les releases.
# La duplication de la config exec est intentionnelle : les providers Kubernetes
# et Helm sont indépendants et chacun gère sa propre connexion au cluster.
# -----------------------------------------------------------------------------
provider "helm" {
  kubernetes {
    host                   = try(module.eks.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        try(module.eks.cluster_name, ""),
        "--region",
        var.aws_region
      ]
    }
  }
}