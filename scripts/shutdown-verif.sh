#!/bin/bash
# shutdown-verif.sh
# Vérifie que toutes les ressources AWS ont bien été détruites.
# A exécuter après shutdown-infra.sh pour s'assurer qu'aucune ressource
# facturante ne reste active.

PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

echo "Vérification de la destruction de l'infrastructure..."
echo ""

cd "${TERRAFORM_DIR}" || exit 1

# Vérification de l'état Terraform local
echo "Etat Terraform :"
if [ -f "terraform.tfstate" ]; then
    RESOURCES=$(terraform show -json | jq '.values.root_module.resources | length' 2>/dev/null || echo "0")
    if [ "$RESOURCES" = "0" ]; then
        echo "  Aucune ressource Terraform active"
    else
        echo "  ATTENTION: $RESOURCES ressource(s) encore présente(s) dans le state"
    fi
else
    echo "  Pas de fichier tfstate"
fi

echo ""
echo "Vérification AWS :"

# VPC
echo -n "  VPC infoline       : "
VPC_COUNT=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*infoline*" --query 'Vpcs | length(@)' --output text 2>/dev/null || echo "0")
[ "$VPC_COUNT" = "0" ] && echo "supprimé" || echo "ENCORE PRESENT ($VPC_COUNT)"

# EKS
# Nom du cluster corrigé : infoline-eks-cluster (était infoline-dev-cluster, ancienne nomenclature)
echo -n "  Cluster EKS        : "
EKS_STATUS=$(aws eks describe-cluster --name infoline-eks-cluster --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
[ "$EKS_STATUS" = "NOT_FOUND" ] && echo "supprimé" || echo "ENCORE PRESENT (status: $EKS_STATUS)"

# EC2
# Filtre sur le nom de cluster corrigé pour retrouver les worker nodes associés
echo -n "  Instances EC2      : "
EC2_COUNT=$(aws ec2 describe-instances \
    --filters "Name=tag:eks:cluster-name,Values=infoline-eks-cluster" \
              "Name=instance-state-name,Values=running,pending" \
    --query 'Reservations[].Instances | length(@)' \
    --output text 2>/dev/null || echo "0")
[ "$EC2_COUNT" = "0" ] && echo "aucune" || echo "ENCORE ACTIVE(S): $EC2_COUNT"

# RDS
echo -n "  RDS PostgreSQL     : "
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier infoline-dev-postgres \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")
[ "$RDS_STATUS" = "NOT_FOUND" ] && echo "supprimé" || echo "ENCORE PRESENT (status: $RDS_STATUS)"

# Lambda
echo -n "  Lambda functions   : "
LAMBDA_COUNT=$(aws lambda list-functions \
    --query 'Functions[?starts_with(FunctionName, `infoline`)].FunctionName | length(@)' \
    --output text 2>/dev/null || echo "0")
[ "$LAMBDA_COUNT" = "0" ] && echo "aucune" || echo "ENCORE PRESENTE(S): $LAMBDA_COUNT"

# Résumé
echo ""
TOTAL_ISSUES=$((VPC_COUNT + EC2_COUNT + LAMBDA_COUNT))
[ "$EKS_STATUS" != "NOT_FOUND" ] && TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
[ "$RDS_STATUS" != "NOT_FOUND" ] && TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

echo "Résumé :"
if [ "$TOTAL_ISSUES" = "0" ]; then
    echo "  Infrastructure complètement détruite"
else
    echo "  ATTENTION: $TOTAL_ISSUES ressource(s) encore active(s) - risque de facturation"
fi