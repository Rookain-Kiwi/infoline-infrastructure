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

echo "🧹 Nettoyage des rôles IAM orphelins..."

# Fonction pour supprimer un rôle proprement
delete_iam_role() {
    local ROLE=$1
    if aws iam get-role --role-name $ROLE &>/dev/null; then
        # Détacher toutes les policies
        for POLICY in $(aws iam list-attached-role-policies --role-name $ROLE --query 'AttachedPolicies[*].PolicyArn' --output text); do
            aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY
            echo "   Détaché: $POLICY"
        done
        # Supprimer le rôle
        aws iam delete-role --role-name $ROLE
        echo "✅ Rôle $ROLE supprimé"
    else
        echo "ℹ️  Rôle $ROLE inexistant"
    fi
}

delete_iam_role "infoline-eks-cluster-cluster-role"
delete_iam_role "infoline-eks-cluster-node-role"
delete_iam_role "infoline-eks-cluster-ebs-csi-driver-role"

echo "✅ Infrastructure arrêtée avec succès"
