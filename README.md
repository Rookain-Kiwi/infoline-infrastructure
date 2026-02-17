# infoline-infrastructure

Infrastructure as Code du projet InfoLine — ECF DevOps (Studi).

Déploie l'ensemble de l'infrastructure AWS via Terraform et les manifests Kubernetes
associés (applications, supervision ELK).

## Repositories du projet

- **[infoline-infrastructure](https://github.com/Rookain-Kiwi/infoline-infrastructure)** (ce repo) : Infrastructure as Code (Terraform, Kubernetes, scripts)
- **[infoline-backend](https://github.com/Rookain-Kiwi/infoline-backend)** : API REST Java Spring Boot
- **[infoline-frontend](https://github.com/Rookain-Kiwi/infoline-frontend)** : Application web Angular

## Stack technique

| Composant         | Technologie                        |
|-------------------|------------------------------------|
| Cloud             | AWS eu-west-3 (Paris)              |
| IaC               | Terraform                          |
| Orchestration     | Amazon EKS (Kubernetes)            |
| Nodes             | EC2 t3.medium ON_DEMAND            |
| Base de données   | Amazon RDS PostgreSQL 16           |
| Registry          | Amazon ECR                         |
| Serverless        | AWS Lambda Node.js 20.x            |
| Supervision       | ELK Stack (Elasticsearch + Kibana) |
| CI/CD             | GitHub Actions                     |

## Architecture réseau

VPC `10.0.0.0/16` déployé sur 3 Availability Zones (eu-west-3a/b/c) :

- **Subnets publics** `10.0.101-103.0/24` — LoadBalancers Kubernetes, NAT Gateways
- **Subnets privés** `10.0.1-3.0/24` — Worker nodes EKS (backend, frontend, ELK)
- **Subnets database** `10.0.201-203.0/24` — RDS PostgreSQL (isolés, pas de route Internet)

## Structure du repository

```
infoline-infrastructure/
├── terraform/
│   ├── main.tf                  # Orchestration des modules
│   ├── variables.tf             # Paramètres configurables
│   ├── outputs.tf               # Valeurs exposées post-déploiement
│   ├── provider.tf              # Providers AWS, Kubernetes, Helm
│   ├── terraform.tfvars.example # Exemple de configuration (ne pas versionner tfvars)
│   └── modules/
│       ├── vpc/                 # Réseau 3 tiers multi-AZ
│       ├── eks/                 # Cluster Kubernetes + IRSA + EBS CSI
│       ├── rds/                 # PostgreSQL 16 (db.t3.micro)
│       ├── ecr/                 # Registres Docker backend et frontend
│       └── lambda/              # Fonction d'authentification serverless
├── kubernetes/
│   ├── namespaces/              # Namespaces applicatifs (infoline-backend, infoline-frontend)
│   └── elk-stack/
│       ├── namespace/           # Namespace elk-stack
│       ├── elasticsearch/       # StatefulSet + Service + PVC
│       └── kibana/              # Deployment + Service + ConfigMap
└── scripts/
    ├── startup-infra.sh         # Recréation complète
    ├── shutdown-infra.sh        # Destruction complète
    ├── shutdown-verif.sh        # Vérification post-destruction
    └── validate-infra.sh        # Validation de l'état après recréation
```

## Prérequis

- Terraform >= 1.0
- AWS CLI configuré (`aws configure`)
- kubectl
- Helm >= 3
- Accès AWS avec crédits suffisants (compte Free Tier + crédits promotionnels)

## Déploiement

### Premier déploiement

```bash
# 1. Copier et renseigner les variables sensibles
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Renseigner db_password dans terraform.tfvars (NE JAMAIS COMMITER CE FICHIER)

# 2. Initialiser et déployer
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 3. Configurer kubectl
aws eks update-kubeconfig --region eu-west-3 --name infoline-eks-cluster

# 4. Installer l'EBS CSI Driver via Helm
EBS_ROLE_ARN=$(terraform output -raw ebs_csi_driver_role_arn)
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$EBS_ROLE_ARN"

# 5. Créer les namespaces
kubectl apply -f kubernetes/namespaces/
kubectl create namespace elk-stack

# 6. Déployer la stack ELK
kubectl apply -f kubernetes/elk-stack/elasticsearch/
kubectl apply -f kubernetes/elk-stack/kibana/
```

### Cycle quotidien (gestion des coûts)

Le projet utilise un cycle destroy/recreate journalier pour limiter les coûts AWS

```bash
# Matin — recréation
./scripts/startup-infra.sh

# Soir — destruction
./scripts/shutdown-infra.sh

# Vérification post-destruction
./scripts/shutdown-verif.sh
```

### Validation de l'infrastructure

```bash
./scripts/validate-infra.sh
```

Exécute 23 checks couvrant : nodes EKS, namespaces, EBS CSI Driver, RDS, ECR,
IAM roles, pods backend/frontend, stack ELK, LoadBalancer Kibana.

## Workflow Git

- `main` — branche stable
- `develop` — développement actif
- `feature/*` — fonctionnalités en cours

## Auteur

Loïc KERGOAT — Promotion THERY