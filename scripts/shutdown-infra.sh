#!/bin/bash
set -e

echo "🛑 Arrêt de l'infrastructure InfoLine..."

cd /home/debian/GIT/infoline

# Créer le dossier backups s'il n'existe pas
mkdir -p ~/backups

# Sauvegarde état
echo "📦 Sauvegarde de l'état Terraform..."
cd infrastructure/terraform
terraform state pull > ~/backups/terraform-state-$(date +%Y%m%d-%H%M).json

# Commit
echo "💾 Commit et synchronisation des modifications..."
cd /home/debian/GIT/infoline
git config pull.rebase false
git pull origin main --no-edit 2>/dev/null || echo "Pas de changement distant"
git add .
git commit -m "chore: sauvegarde avant arrêt - $(date +%Y-%m-%d)" || echo "Rien à commiter"
git push origin main

# Destruction
echo "🔥 Destruction de l'infrastructure..."
cd infrastructure/terraform
terraform destroy -auto-approve

# Log
mkdir -p /home/debian/GIT/infoline/logs
echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure détruite" >> /home/debian/GIT/infoline/logs/infrastructure.log

echo "✅ Infrastructure arrêtée avec succès"
