#!/bin/bash
set -e

echo "🛑 Arrêt de l'infrastructure InfoLine..."

# Changement 1 : Nouveau chemin du repo
cd /home/debian/GIT/infoline-infrastructure/terraform

echo "💣 Destruction de l'infrastructure..."
terraform destroy -auto-approve

# Changement 2 : Nouveau chemin pour les logs (optionnel)
# mkdir -p /home/debian/logs/infoline
# echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure détruite" >> /home/debian/logs/infoline/infrastructure.log

echo "✅ Infrastructure arrêtée avec succès"
echo "💰 Économie de coûts AWS activée"
