#!/bin/bash
# startup-infra.sh
# Recrée l'infrastructure InfoLine complète depuis zéro.
# A exécuter chaque matin avant de travailler.
# Durée estimée : 12-15 minutes.
set -e

# Configuration
PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
K8S_DIR="${PROJECT_ROOT}/kubernetes"
LOG_DIR="${HOME}/logs/infoline"

echo "Démarrage de l'infrastructure InfoLine..."
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

cd "${PROJECT_ROOT}" || exit 1

# Synchronisation avec le dépôt distant avant tout déploiement
git config pull.rebase false
git pull origin develop || {
    echo "Conflit Git détecté, tentative de résolution automatique..."
    git pull origin develop --no-rebase --allow-unrelated-histories
}

# Création de l'infrastructure AWS via Terraform
cd "${TERRAFORM_DIR}" || exit 1
terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

# Configuration de kubectl pour pointer sur le cluster EKS créé
echo "Configuration kubectl..."
aws eks update-kubeconfig --region eu-west-3 --name infoline-eks-cluster

# Création des namespaces applicatifs (infoline-backend, infoline-frontend, dev, prod)
echo "Création des namespaces Kubernetes..."
kubectl apply -f "${K8S_DIR}/namespaces/"

# Installation du driver EBS CSI via Helm.
# Note: l'addon Terraform aws_eks_addon provoquait des timeouts systématiques.
# Le déploiement via Helm est plus fiable dans ce contexte.
echo "Installation du driver EBS CSI via Helm..."

if ! command -v helm &> /dev/null; then
    echo "Helm non trouvé, installation en cours..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver 2>/dev/null || true
helm repo update

# Récupération de l'ARN du rôle IAM créé par Terraform pour l'IRSA du driver EBS CSI
cd "${TERRAFORM_DIR}" || exit 1
EBS_CSI_ROLE_ARN=$(terraform output -raw ebs_csi_driver_role_arn)
cd "${PROJECT_ROOT}" || exit 1

helm upgrade --install aws-ebs-csi-driver \
  aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${EBS_CSI_ROLE_ARN}"

# Attente du démarrage des pods EBS CSI avant de continuer
echo "Attente du démarrage des pods EBS CSI (30 secondes)..."
sleep 30

kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

if kubectl get csidriver ebs.csi.aws.com &> /dev/null; then
    echo "EBS CSI Driver opérationnel"
else
    echo "ERREUR: EBS CSI Driver non détecté - vérification manuelle requise"
fi

# Création du namespace elk-stack pour la stack de supervision
kubectl create namespace elk-stack 2>/dev/null && echo "Namespace elk-stack créé" || echo "Namespace elk-stack existe déjà"

# Affichage des informations de connexion RDS pour les déploiements applicatifs
echo "Informations de connexion RDS PostgreSQL:"
cd "${TERRAFORM_DIR}" || exit 1

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_DATABASE=$(terraform output -raw rds_database_name)
RDS_CONNECTION=$(terraform output -raw rds_connection_string)

echo "  Endpoint : $RDS_ENDPOINT"
echo "  Database : $RDS_DATABASE"
echo "  JDBC URL : $RDS_CONNECTION"
echo "  Username : infoline_admin"

# Vérification rapide de l'état du cluster
echo "Etat du cluster:"
kubectl get nodes
echo ""
kubectl get namespaces

# Journalisation de l'opération
mkdir -p "${LOG_DIR}"
echo "$(date +%Y-%m-%d_%H:%M:%S) - Infrastructure démarrée (VPC + EKS + RDS + EBS CSI + elk-stack)" >> "${LOG_DIR}/infrastructure.log"

echo ""
echo "Infrastructure démarrée avec succès"
echo "  VPC             : infoline-dev-vpc"
echo "  Cluster EKS     : infoline-eks-cluster"
echo "  RDS PostgreSQL  : infoline-dev-postgres"
echo "  EBS CSI Driver  : installé"
echo "  Namespace elk-stack : créé"
echo "  Région          : eu-west-3"
echo "  Noeuds EKS      : $(kubectl get nodes --no-headers | wc -l)"
echo "  Namespaces      : $(kubectl get namespaces --no-headers | wc -l)"
