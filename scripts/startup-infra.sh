#!/bin/bash
set -e

echo "▶️  Démarrage de l'infrastructure InfoLine..."
echo "📅 Date: $(date '+%Y-%m-%d %H:%M:%S')"

# Changement de répertoire
cd /home/debian/GIT/infoline-infrastructure

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

cd terraform
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# Configuration kubectl
echo ""
echo "⚙️  Configuration kubectl..."
aws eks update-kubeconfig --region eu-west-3 --name infoline-dev-cluster

# Application des namespaces
echo "📦 Création des namespaces Kubernetes..."
cd ..
kubectl apply -f kubernetes/namespaces/

# Récupération des informations RDS
echo ""
echo "🗄️  Informations de connexion RDS PostgreSQL:"
cd terraform
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_DATABASE=$(terraform output -raw rds_database_name)
RDS_CONNECTION=$(terraform output -raw rds_connection_string)

echo "   - Endpoint: $RDS_ENDPOINT"
echo "   - Database: $RDS_DATABASE"
echo "   - JDBC URL: $RDS_CONNECTION"
echo "   - Username: infoline_admin"
echo ""
cd ..

# Vérifications
echo "🔍 Vérification de l'infrastructure..."
kubectl get nodes
echo ""
kubectl get namespaces

# Logs
mkdir -p /home/debian/logs/infoline
echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure recréée (VPC + EKS + RDS)" >> /home/debian/logs/infoline/infrastructure.log

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