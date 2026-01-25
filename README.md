# InfoLine - Infrastructure

Infrastructure as Code.

**TP Administrateur Système DevOps - Studi**

## 📋 Vue d'ensemble du projet

InfoLine est déployé sur AWS avec une architecture cloud-native moderne, utilisant une approche multi-repositories pour une séparation claire des responsabilités.

### Repositories du projet

- **[infoline-infrastructure](https://github.com/Rookain-Kiwi/infoline-infrastructure)** (ce repo) : Infrastructure as Code (Terraform, Kubernetes)
- **[infoline-backend](https://github.com/Rookain-Kiwi/infoline-backend)** : API REST Java Spring Boot
- **[infoline-frontend](https://github.com/Rookain-Kiwi/infoline-frontend)** : Application web Angular

## 🏗️ Architecture

### Stack Technique

- **Cloud Provider** : AWS (région eu-west-3)
- **Orchestration** : Amazon EKS (Kubernetes)
- **IaC** : Terraform
- **CI/CD** : GitHub Actions
- **Serverless** : AWS Lambda (authentification)
- **Base de données** : Amazon RDS PostgreSQL
- **Container Registry** : Amazon ECR
- **Monitoring** : ELK Stack (Elasticsearch, Logstash, Kibana)

### Infrastructure déployée

- **VPC multi-AZ** avec subnets publics et privés
- **EKS Cluster** avec namespaces `dev` et `prod`
- **Lambda** pour l'authentification utilisateur
- **RDS PostgreSQL** (à venir)
- **ELK Stack** pour la supervision (à venir)

## 📁 Structure du repository
```
infoline-infrastructure/
├── terraform/              # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/           # Configuration réseau
│   │   └── eks/           # Cluster Kubernetes
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── kubernetes/            # Manifests Kubernetes
│   └── namespaces/       # Namespaces dev/prod
├── scripts/              # Scripts d'automatisation
│   ├── startup-infra.sh  # Création infrastructure
│   ├── shutdown-infra.sh # Destruction infrastructure
│   └── shutdown-verif.sh # Vérification destruction
└── docs/                 # Documentation technique
```

## 💰 Gestion des coûts AWS

Le projet utilise AWS Education credits avec une stratégie de gestion stricte des coûts :

- **Instances EKS** : t3.micro (Free Tier compatible)
- **Cycle quotidien** : Destruction automatique le soir, recréation le matin
- **Économie estimée** : ~67 USD sur la durée du projet

### Scripts de gestion
```bash
# Destruction de l'infrastructure (5-8 min)
./scripts/shutdown-infra.sh

# Recréation de l'infrastructure (12-15 min)
./scripts/startup-infra.sh

# Vérification de la destruction complète
./scripts/shutdown-verif.sh
```

## 🚀 Déploiement

### Prérequis

- Terraform >= 1.0
- AWS CLI configuré
- kubectl
- Accès AWS avec crédits suffisants

### Déploiement initial
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Configuration kubectl
```bash
aws eks update-kubeconfig --region eu-west-3 --name infoline-eks-cluster
kubectl get nodes
kubectl get namespaces
```

## 🔄 Workflow Git

- **main** : branche stable, déployée en production
- **develop** : branche de développement
- **feature/*** : branches de fonctionnalités

Tous les commits suivent la convention [Conventional Commits](https://www.conventionalcommits.org/).

## 📚 Documentation

- [Architecture détaillée](docs/) (à venir)
- [Guide de gestion des coûts](docs/) (à venir)
- [Procédures de déploiement](docs/) (à venir)

## 👤 Auteur

**Loïc KERGOAT** - Promotion THERY  
TP Administrateur Système DevOps - Studi  
Janvier 2026
