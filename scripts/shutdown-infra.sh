#!/bin/bash
# shutdown-infra.sh
# Détruit l'infrastructure InfoLine complète pour réduire les coûts AWS.
# A exécuter chaque soir en fin de session.
# Durée estimée : 5-8 minutes.
set -e

PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo "Arrêt de l'infrastructure InfoLine..."

cd "${TERRAFORM_DIR}" || exit 1

# Suppression explicite des services LoadBalancer Kubernetes avant le destroy Terraform.
# Les LoadBalancers AWS créés par Kubernetes (Kibana) ne sont pas dans le state Terraform
# et bloquent la suppression du VPC : l'IGW ne peut pas être détaché tant qu'une adresse
# publique est mappée, et les subnets ne peuvent pas être supprimés tant qu'un LB les utilise.
echo "Suppression des LoadBalancers Kubernetes..."
kubectl delete svc kibana-svc -n elk-stack 2>/dev/null || true
kubectl delete svc infoline-backend-service -n infoline-backend 2>/dev/null || true
kubectl delete svc infoline-frontend-service -n infoline-frontend 2>/dev/null || true

# Attente du déprovisionment effectif des LoadBalancers AWS (30 secondes).
# Sans cette attente, Terraform peut tenter de supprimer les subnets
# avant que les ENI des LB soient libérées.
echo "Attente du déprovisionment des LoadBalancers AWS (30 secondes)..."
sleep 30

terraform destroy -auto-approve

# Nettoyage des rôles IAM orphelins.
# Terraform ne supprime pas toujours les rôles IAM proprement en cas d'erreur
# intermédiaire lors du destroy. Cette fonction assure leur suppression complète.
echo "Nettoyage des rôles IAM orphelins..."

delete_iam_role() {
    local ROLE=$1
    if aws iam get-role --role-name $ROLE &>/dev/null; then
        for POLICY in $(aws iam list-attached-role-policies --role-name $ROLE --query 'AttachedPolicies[*].PolicyArn' --output text); do
            aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY
            echo "  Policy détachée: $POLICY"
        done
        aws iam delete-role --role-name $ROLE
        echo "  Role supprimé: $ROLE"
    else
        echo "  Role inexistant (déjà supprimé): $ROLE"
    fi
}

delete_iam_role "infoline-eks-cluster-cluster-role"
delete_iam_role "infoline-eks-cluster-node-role"
delete_iam_role "infoline-eks-cluster-ebs-csi-driver-role"

echo "Infrastructure arrêtée avec succès"
