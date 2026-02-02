#!/bin/bash
set -e

# === Configuration ===
PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
K8S_DIR="${PROJECT_ROOT}/kubernetes"
LOG_DIR="${HOME}/logs/infoline"

# === Démarrage de l'infrastructure ===
echo "▶️  Démarrage de l'infrastructure InfoLine..."
echo "📅 Date: $(date '+%Y-%m-%d %H:%M:%S')"

# Changement de répertoire
cd "${PROJECT_ROOT}" || exit 1

# Pull des dernières modifications
echo "📥 Récupération des dernières modifications..."
git config pull.rebase false
git pull origin develop || {
    echo "⚠️  Conflit Git détecté, résolution automatique..."
    git pull origin develop --no-rebase --allow-unrelated-histories
}

# Apply Terraform
echo "🚀 Création de l'infrastructure..."
echo ""
cd "${TERRAFORM_DIR}" || exit 1

terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# Configuration kubectl
echo ""
echo "⚙️  Configuration kubectl..."
aws eks update-kubeconfig --region eu-west-3 --name infoline-dev-cluster

# Application des namespaces
echo "📦 Création des namespaces Kubernetes..."
kubectl apply -f "${K8S_DIR}/namespaces/"

# Récupération des informations RDS
echo ""
echo "🗄️  Informations de connexion RDS PostgreSQL:"
cd "${TERRAFORM_DIR}" || exit 1

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_DATABASE=$(terraform output -raw rds_database_name)
RDS_CONNECTION=$(terraform output -raw rds_connection_string)

echo "   - Endpoint: $RDS_ENDPOINT"
echo "   - Database: $RDS_DATABASE"
echo "   - JDBC URL: $RDS_CONNECTION"
echo "   - Username: infoline_admin"
echo ""

# Vérifications
echo "🔍 Vérification de l'infrastructure..."
kubectl get nodes
echo ""
kubectl get namespaces

# Logs
mkdir -p "${LOG_DIR}"
echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure recréée (VPC + EKS + RDS)" >> "${LOG_DIR}/infrastructure.log"

echo ""
echo "✅ Infrastructure démarrée avec succès"
echo ""
echo "📊 Résumé de l'infrastructure :"
echo "   🌐 VPC : infoline-dev-vpc"
echo "   ☸️  Cluster EKS : infoline-dev-cluster"
echo "   🗄️  RDS PostgreSQL : infoline-dev-postgres"
echo "   📍 Région : eu-west-3"
echo "   🖥️  Nœuds EKS : $(kubectl get nodes --no-headers | wc -l)"
echo "   📦 Namespaces : $(kubectl get namespaces --no-headers | wc -l)"