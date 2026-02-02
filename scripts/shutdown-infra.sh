#!/bin/bash
set -e

# === Configuration ===
PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

# === Arrêt de l'infrastructure ===
echo "🛑 Arrêt de l'infrastructure InfoLine..."

cd "${TERRAFORM_DIR}" || exit 1

echo "💣 Destruction de l'infrastructure..."
terraform destroy -auto-approve

echo "✅ Infrastructure arrêtée avec succès"
