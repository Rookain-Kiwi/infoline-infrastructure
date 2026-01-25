#!/bin/bash

echo "🔍 Vérification de la destruction de l'infrastructure"
echo "===================================================="
echo ""

echo "1️⃣ Clusters EKS restants :"
aws eks list-clusters --region eu-west-3
echo ""

echo "2️⃣ Instances EC2 avec tag infoline :"
aws ec2 describe-instances --region eu-west-3 \
  --filters "Name=tag:Project,Values=infoline" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType]' \
  --output table
echo ""

echo "3️⃣ Lambda functions infoline :"
aws lambda list-functions --region eu-west-3 \
  --query 'Functions[?contains(FunctionName, `infoline`)].FunctionName' \
  --output table
echo ""

echo "4️⃣ VPC avec tag infoline :"
aws ec2 describe-vpcs --region eu-west-3 \
  --filters "Name=tag:Project,Values=infoline" \
  --query 'Vpcs[*].[VpcId,State,CidrBlock]' \
  --output table
echo ""

echo "5️⃣ Log de destruction :"
if [ -f /home/debian/GIT/infoline/logs/infrastructure.log ]; then
  tail -5 /home/debian/GIT/infoline/logs/infrastructure.log
else
  echo "Fichier de log non trouvé"
fi
echo ""

echo "===================================================="
echo "✅ Résultats attendus :"
echo "  - Clusters EKS : liste vide {}"
echo "  - Instances EC2 : aucune ou toutes 'terminated'"
echo "  - Lambda : liste vide"
echo "  - VPC : liste vide ou aucun avec tag infoline"
echo "  - Log : dernière ligne avec timestamp de destruction"
echo ""
echo "🔄 Si des ressources subsistent :"
echo "  cd /home/debian/GIT/infoline/infrastructure/terraform"
echo "  terraform destroy -auto-approve"

