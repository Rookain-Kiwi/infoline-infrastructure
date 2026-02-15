# ==============================================================================
# MODULE ECR - Registres d'images Docker InfoLine
# ==============================================================================
# Déploie les dépôts Amazon ECR pour stocker les images Docker du backend 
# Spring Boot et du frontend Angular.
#
# Intégration dans le pipeline CI/CD :
# GitHub Actions → build image → docker push → ECR → EKS pull image
#
# Les worker nodes EKS ont accès en lecture via la policy IAM
# AmazonEC2ContainerRegistryReadOnly attachée au node role (module EKS).
# ==============================================================================

# ------------------------------------------------------------------------------
# ECR Repository - Backend Spring Boot
# ------------------------------------------------------------------------------
# image_tag_mutability = "MUTABLE" : un même tag (ex: "latest") peut être
# réutilisé pour pointer vers une nouvelle image à chaque déploiement CI/CD.
#
# force_delete = true : permet à terraform destroy de supprimer le dépôt
# même s'il contient des images. Sans ce flag, le destroy échoue
# bloquant le cycle destroy/recreate journalier.
# Résout l'erreur rencontrée lors des premières itérations du projet.
#
# scan_on_push = true : analyse de vulnérabilités automatique à chaque push
# via AWS Inspector. Résultats visibles dans la console ECR, sans surcoût 
# pour les comptes Free Tier
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "backend" {
  name                 = "infoline-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "infoline-backend"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# Lifecycle Policy - Backend
# ------------------------------------------------------------------------------
# Limite le dépôt à 5 images maximum (tous tags confondus).
# Quand une 6ème image est pushée, la plus ancienne est supprimée
# automatiquement par ECR.
#
# tagStatus = "any" : s'applique aux images taguées ET non taguées
# (les builds intermédiaires sans tag s'accumulent trop vite sans cette règle).
#
# Justification countNumber = 5 :
# Conserve les 5 derniers déploiements → rollback possible sur 5 versions
# Limite le stockage ECR facturé (500MB Free Tier/mois)
# ------------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# ------------------------------------------------------------------------------
# ECR Repository - Frontend Angular
# ------------------------------------------------------------------------------
# Même configuration que le backend — dépôt dédié pour isoler les cycles
# de déploiement : un push backend ne déclenche pas de rebuild frontend
# et vice versa (les pipelines GitHub Actions doivent être indépendants).
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "frontend" {
  name                 = "infoline-frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "infoline-frontend"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# Lifecycle Policy - Frontend
# ------------------------------------------------------------------------------
# Identique à la policy backend : 5 images maximum, nettoyage automatique
# des images en trop par ordre d'ancienneté.
# ------------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}