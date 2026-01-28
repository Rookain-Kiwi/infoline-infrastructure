#!/bin/bash
set -e

echo "🛑 Arrêt de l'infrastructure InfoLine..."

cd /home/debian/GIT/infoline-infrastructure/terraform

echo "💣 Destruction de l'infrastructure..."
terraform destroy -auto-approve

echo "✅ Infrastructure arrêtée avec succès"
