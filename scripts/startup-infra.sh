#!/bin/bash
set -e

echo "▶️ Démarrage de l'infrastructure InfoLine..."

# Changement 1 : Nouveau chemin du repo
cd /home/debian/GIT/infoline-infrastructure

# Pull
echo "📥 Récupération des dernières modifications..."
git config pull.rebase false
git pull origin main || {
    echo "⚠️ Conflit Git détecté, résolution automatique..."
    git pull origin main --no-rebase --allow-unrelated-histories
}

# Apply
echo "🚀 Création de l'infrastructure..."
# Changement 2 : Nouveau chemin Terraform
cd terraform
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# Configure kubectl
echo "⚙️ Configuration kubectl..."
aws eks update-kubeconfig --region eu-west-3 --name infoline-eks-cluster

# Changement 3 : Appliquer les namespaces depuis les manifests YAML
echo "📦 Création des namespaces..."
cd ..
kubectl apply -f kubernetes/namespaces/

# Vérifications
echo "🔍 Vérification..."
kubectl get nodes
kubectl get namespaces

# Changement 4 : Nouveau chemin pour les logs (optionnel, ou on supprime)
# Note : Les logs ne sont plus versionnés (dans .gitignore)
# mkdir -p /home/debian/logs/infoline
# echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure recréée" >> /home/debian/logs/infoline/infrastructure.log

echo "✅ Infrastructure démarrée avec succès"
echo ""
echo "📊 Résumé de l'infrastructure :"
echo "- Cluster EKS : infoline-eks-cluster"
echo "- Région : eu-west-3"
echo "- Nœuds : $(kubectl get nodes --no-headers | wc -l)"
echo "- Namespaces : $(kubectl get namespaces --no-headers | wc -l)"
