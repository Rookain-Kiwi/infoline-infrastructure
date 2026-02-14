#!/bin/bash
# shutdown-infra.sh
# Détruit l'infrastructure InfoLine complète pour réduire les coûts AWS.
# A exécuter chaque soir en fin de session.
# Durée estimée : 15-20 minutes.
#
# Ordre de suppression important :
# 1. LoadBalancers Kubernetes (pendant que kubectl est encore fonctionnel)
# 2. Node group EKS (libère les instances EC2)
# 3. Cluster EKS (libère les ENI du control plane)
# 4. terraform destroy (VPC, subnets, IGW, RDS, Lambda, ECR)
# 5. Nettoyage des rôles IAM orphelins
#
# Les étapes 1-3 sont nécessaires car les ressources créées par Kubernetes
# (LoadBalancers, ENI du control plane) ne sont pas dans le state Terraform
# et bloquent la suppression du VPC si elles sont encore actives.
set -e

PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo "Arrêt de l'infrastructure InfoLine..."
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

cd "${TERRAFORM_DIR}" || exit 1

# Etape 1 : Suppression des services LoadBalancer Kubernetes.
# Doit être fait avant la suppression du cluster, pendant que kubectl fonctionne.
# Les LB AWS associés doivent être déprovisionnnés avant la suppression des subnets.
echo "Suppression des LoadBalancers Kubernetes..."
kubectl delete svc kibana-svc -n elk-stack 2>/dev/null || true
kubectl delete svc infoline-backend-service -n infoline-backend 2>/dev/null || true
kubectl delete svc infoline-frontend-service -n infoline-frontend 2>/dev/null || true

echo "Attente du déprovisionment des LoadBalancers AWS (60 secondes)..."
sleep 60

# Etape 2 : Suppression du node group EKS.
# Le cluster ne peut pas être supprimé tant que des node groups y sont attachés.
echo "Suppression du node group EKS..."
aws eks delete-nodegroup \
    --cluster-name infoline-eks-cluster \
    --nodegroup-name infoline-eks-cluster-node-group \
    --no-cli-pager 2>/dev/null || true

echo "Attente de la suppression du node group..."
while true; do
    STATUS=$(aws eks describe-nodegroup \
        --cluster-name infoline-eks-cluster \
        --nodegroup-name infoline-eks-cluster-node-group \
        --query 'nodegroup.status' \
        --output text 2>/dev/null || echo "DELETED")
    if [ "$STATUS" = "DELETED" ]; then
        echo "  Node group supprimé."
        break
    fi
    echo "  Node group status: $STATUS - attente 30 secondes..."
    sleep 30
done

# Etape 3 : Suppression du cluster EKS.
# Les ENI du control plane EKS (gérées par AWS, hors state Terraform) bloquent
# la suppression du VPC. Elles sont libérées automatiquement à la suppression du cluster.
echo "Suppression du cluster EKS..."
aws eks delete-cluster --name infoline-eks-cluster \
    --no-cli-pager 2>/dev/null || true

echo "Attente de la suppression du cluster EKS..."
while true; do
    STATUS=$(aws eks describe-cluster \
        --name infoline-eks-cluster \
        --query 'cluster.status' \
        --output text 2>/dev/null || echo "DELETED")
    if [ "$STATUS" = "DELETED" ]; then
        echo "  Cluster supprimé."
        break
    fi
    echo "  Cluster status: $STATUS - attente 30 secondes..."
    sleep 30
done

# Attente supplémentaire pour la libération effective des ENI par AWS.
# AWS peut prendre quelques dizaines de secondes après la suppression du cluster
# pour détacher et libérer les ENI associées au control plane.
echo "Attente de la libération des ENI EKS (60 secondes)..."
sleep 60

# Etape 4 : Destruction du reste de l'infrastructure via Terraform.
echo "Destruction de l'infrastructure Terraform..."
terraform destroy -auto-approve

# Etape 5 : Nettoyage des rôles IAM orphelins.
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

echo ""
echo "Infrastructure arrêtée avec succès."
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"