#!/bin/bash
set -e

echo "▶️ Démarrage de l'infrastructure InfoLine..."

cd /home/debian/GIT/infoline

# Pull
echo "📥 Récupération des dernières modifications..."
git config pull.rebase false
git pull origin main || {
  echo "⚠️ Conflit Git détecté, résolution automatique..."
  git pull origin main --no-rebase --allow-unrelated-histories
}

# Apply
echo "🚀 Création de l'infrastructure..."
cd infrastructure/terraform
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
echo "⚙️ Configuration kubectl..."
aws eks update-kubeconfig --region eu-west-3 --name infoline-eks-cluster

# Vérifications
echo "🔍 Vérification..."
kubectl get nodes
kubectl get namespaces

# Log
mkdir -p /home/debian/GIT/infoline/logs
echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure recréée" >> /home/debian/GIT/infoline/logs/infrastructure.log

echo "✅ Infrastructure démarrée avec succès"
echo ""
echo "📊 Résumé de l'infrastructure :"
echo "- Cluster EKS : infoline-eks-cluster"
echo "- Région : eu-west-3"
echo "- Nœuds : $(kubectl get nodes --no-headers | wc -l)"
echo "- Namespaces : $(kubectl get namespaces --no-headers | wc -l)"
