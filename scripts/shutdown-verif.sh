#!/bin/bash

echo "🔍 Vérification de la destruction complète de l'infrastructure..."
echo ""

cd /home/debian/GIT/infoline-infrastructure/terraform

# Vérification Terraform
echo "📋 État Terraform :"
if [ -f "terraform.tfstate" ]; then
  RESOURCES=$(terraform show -json | jq '.values.root_module.resources | length' 2>/dev/null || echo "0")
  if [ "$RESOURCES" = "0" ]; then
    echo "✅ Aucune ressource Terraform active"
  else
    echo "⚠️  $RESOURCES ressource(s) Terraform encore présente(s)"
  fi
else
  echo "✅ Pas de fichier tfstate (infrastructure jamais créée ou détruite)"
fi

echo ""
echo "☁️  Vérification AWS :"

# VPC
echo -n "VPC infoline : "
VPC_COUNT=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*infoline*" --query 'Vpcs | length(@)' --output text 2>/dev/null || echo "0")
if [ "$VPC_COUNT" = "0" ]; then
  echo "✅ Supprimé"
else
  echo "⚠️  Encore présent ($VPC_COUNT)"
fi

# EKS
echo -n "Cluster EKS : "
EKS_STATUS=$(aws eks describe-cluster --name infoline-dev-cluster --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$EKS_STATUS" = "NOT_FOUND" ]; then
  echo "✅ Supprimé"
else
  echo "⚠️  Status: $EKS_STATUS"
fi

# EC2
echo -n "Instances EC2 : "
EC2_COUNT=$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=infoline-dev-cluster" "Name=instance-state-name,Values=running,pending" --query 'Reservations[].Instances | length(@)' --output text 2>/dev/null || echo "0")
if [ "$EC2_COUNT" = "0" ]; then
  echo "✅ Aucune instance"
else
  echo "⚠️  $EC2_COUNT instance(s) encore active(s)"
fi

# RDS PostgreSQL
echo -n "RDS PostgreSQL : "
RDS_STATUS=$(aws rds describe-db-instances --db-instance-identifier infoline-dev-postgres --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$RDS_STATUS" = "NOT_FOUND" ]; then
  echo "✅ Supprimé"
else
  echo "⚠️  Status: $RDS_STATUS"
fi

# Lambda
echo -n "Lambda functions : "
LAMBDA_COUNT=$(aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `infoline`)].FunctionName | length(@)' --output text 2>/dev/null || echo "0")
if [ "$LAMBDA_COUNT" = "0" ]; then
  echo "✅ Aucune fonction"
else
  echo "⚠️  $LAMBDA_COUNT fonction(s) encore présente(s)"
fi

echo ""
echo "📊 Résumé :"

# Calcul des problèmes
TOTAL_ISSUES=$((VPC_COUNT + EC2_COUNT + LAMBDA_COUNT))

if [ "$EKS_STATUS" != "NOT_FOUND" ]; then
  TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

if [ "$RDS_STATUS" != "NOT_FOUND" ]; then
  TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

if [ "$TOTAL_ISSUES" = "0" ]; then
  echo "✅ Infrastructure complètement détruite"
else
  echo "⚠️  $TOTAL_ISSUES ressource(s) encore active(s)"
fi