#!/bin/bash
# validate-infra.sh
# Vérifie l'état complet de l'infrastructure InfoLine en 3 phases.
# Phase 1 : ressources AWS (EKS, RDS, ECR, IAM)
# Phase 2 : applications déployées (backend, frontend)
# Phase 3 : stack de supervision (Elasticsearch, Kibana)

PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
REGION="eu-west-3"
CLUSTER_NAME="infoline-eks-cluster"

PASS=0
FAIL=0
WARN=0

check_pass() { echo "  [OK]  $1"; PASS=$((PASS + 1)); }
check_fail() { echo "  [KO]  $1"; FAIL=$((FAIL + 1)); }
check_warn() { echo "  [--]  $1"; WARN=$((WARN + 1)); }
section()    { echo ""; echo "========================================"; echo "  $1"; echo "========================================"; }

# Compte le nombre de lignes contenant un pattern dans une sortie kubectl.
# Evite le problème de grep -c qui retourne "0\n0" quand stderr est redirigé dans le pipe.
count_running() {
    echo "$1" | grep -c "Running" || true
}

echo "========================================"
echo "  VALIDATION INFRASTRUCTURE INFOLINE"
echo "========================================"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

# ============================================================
# PHASE 1 : INFRASTRUCTURE AWS
# ============================================================
section "PHASE 1 : INFRASTRUCTURE AWS"

# Nodes EKS
echo ""
echo "Nodes EKS :"
NODE_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || true)
NODE_READY=${NODE_READY:-0}
if [ "$NODE_READY" -ge 2 ]; then
    check_pass "$NODE_READY nodes Ready"
else
    check_fail "Seulement $NODE_READY nodes Ready (attendu: 2)"
fi

# Vérification du type d'instance.
# t3.medium requis : t3.small insuffisant pour Elasticsearch (OOMKilled).
INSTANCE_TYPE=$(aws ec2 describe-instances --region $REGION \
    --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceType' \
    --output text 2>/dev/null)
if [ "$INSTANCE_TYPE" = "t3.medium" ]; then
    check_pass "Instance type: t3.medium"
else
    check_fail "Instance type: $INSTANCE_TYPE (attendu: t3.medium)"
fi

# Namespaces
echo ""
echo "Namespaces Kubernetes :"
for NS in elk-stack infoline-backend infoline-frontend; do
    if kubectl get namespace $NS &>/dev/null; then
        check_pass "Namespace $NS"
    else
        check_fail "Namespace $NS manquant"
    fi
done

# EBS CSI Driver
# Requis pour le provisionnement dynamique des PersistentVolumes EBS (Elasticsearch).
echo ""
echo "EBS CSI Driver :"
EBS_PODS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver \
    --no-headers 2>/dev/null || true)
EBS_RUNNING=$(count_running "$EBS_PODS")
if [ "$EBS_RUNNING" -ge 4 ]; then
    check_pass "EBS CSI Driver: $EBS_RUNNING pods Running"
else
    check_fail "EBS CSI Driver: $EBS_RUNNING pods Running (attendu: >= 4)"
fi

# RDS PostgreSQL
echo ""
echo "RDS PostgreSQL :"
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier infoline-dev-postgres \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$RDS_STATUS" = "available" ]; then
    check_pass "RDS PostgreSQL: available"
else
    check_fail "RDS PostgreSQL: $RDS_STATUS (attendu: available)"
fi

# ECR Repositories
echo ""
echo "ECR Repositories :"
for REPO in infoline-backend infoline-frontend; do
    REPO_EXISTS=$(aws ecr describe-repositories \
        --region $REGION \
        --repository-names $REPO \
        --query 'repositories[0].repositoryName' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    if [ "$REPO_EXISTS" = "$REPO" ]; then
        IMAGE_COUNT=$(aws ecr list-images \
            --region $REGION \
            --repository-name $REPO \
            --query 'imageIds | length(@)' \
            --output text 2>/dev/null || echo "0")
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            check_pass "ECR $REPO: $IMAGE_COUNT image(s)"
        else
            check_warn "ECR $REPO: dépôt vide (pipeline CI/CD non déclenché ?)"
        fi
    else
        check_fail "ECR $REPO: manquant"
    fi
done

# IAM Roles
echo ""
echo "IAM Roles :"
for ROLE in infoline-eks-cluster-cluster-role infoline-eks-cluster-node-role infoline-eks-cluster-ebs-csi-driver; do
    if aws iam get-role --role-name $ROLE &>/dev/null; then
        check_pass "$ROLE"
    else
        check_fail "$ROLE manquant"
    fi
done

# Utilisation mémoire (informatif)
echo ""
echo "Utilisation mémoire nodes :"
kubectl describe nodes 2>/dev/null | grep -A 3 "Allocated resources" | grep memory | head -2 | while read line; do
    echo "  $line"
done

# ============================================================
# PHASE 2 : APPLICATIONS CI/CD
# ============================================================
section "PHASE 2 : APPLICATIONS CI/CD"

# Backend Spring Boot
echo ""
echo "Backend Spring Boot :"
BACKEND_PODS=$(kubectl get pods -n infoline-backend --no-headers 2>/dev/null || true)
BACKEND_RUNNING=$(count_running "$BACKEND_PODS")
if [ "$BACKEND_RUNNING" -ge 1 ]; then
    check_pass "Backend: $BACKEND_RUNNING pod(s) Running"
else
    check_fail "Backend: aucun pod Running"
fi

BACKEND_SVC=$(kubectl get svc -n infoline-backend --no-headers 2>/dev/null | wc -l || true)
BACKEND_SVC=${BACKEND_SVC:-0}
if [ "$BACKEND_SVC" -ge 1 ]; then
    check_pass "Backend service: présent"
else
    check_warn "Backend service: non trouvé"
fi

# Frontend Angular
echo ""
echo "Frontend Angular :"
FRONTEND_PODS=$(kubectl get pods -n infoline-frontend --no-headers 2>/dev/null || true)
FRONTEND_RUNNING=$(count_running "$FRONTEND_PODS")
if [ "$FRONTEND_RUNNING" -ge 1 ]; then
    check_pass "Frontend: $FRONTEND_RUNNING pod(s) Running"
else
    check_fail "Frontend: aucun pod Running"
fi

FRONTEND_SVC=$(kubectl get svc -n infoline-frontend --no-headers 2>/dev/null | wc -l || true)
FRONTEND_SVC=${FRONTEND_SVC:-0}
if [ "$FRONTEND_SVC" -ge 1 ]; then
    check_pass "Frontend service: présent"
else
    check_warn "Frontend service: non trouvé"
fi

# Dernières images ECR
echo ""
echo "Images Docker ECR :"
for REPO in infoline-backend infoline-frontend; do
    LATEST_TAG=$(aws ecr describe-images \
        --region $REGION \
        --repository-name $REPO \
        --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' \
        --output text 2>/dev/null || echo "none")
    if [ "$LATEST_TAG" != "none" ] && [ "$LATEST_TAG" != "None" ]; then
        check_pass "$REPO: ${LATEST_TAG:0:20}"
    else
        check_warn "$REPO: aucune image"
    fi
done

# ============================================================
# PHASE 3 : ELK STACK SUPERVISION
# ============================================================
section "PHASE 3 : ELK STACK SUPERVISION"

# Elasticsearch
echo ""
echo "Elasticsearch :"
ES_PODS=$(kubectl get pods -n elk-stack -l app=elasticsearch --no-headers 2>/dev/null || true)
ES_RUNNING=$(count_running "$ES_PODS")
if [ "$ES_RUNNING" -ge 1 ]; then
    check_pass "Elasticsearch pod: Running"

    # Vérification santé du cluster via l'API REST
    ES_STATUS=$(kubectl exec -n elk-stack elasticsearch-0 -- \
        curl -s http://localhost:9200/_cluster/health \
        --max-time 5 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$ES_STATUS" = "green" ]; then
        check_pass "Elasticsearch cluster: GREEN"
    elif [ "$ES_STATUS" = "yellow" ]; then
        # Yellow normal en single-node : les réplicas ne peuvent pas être assignés
        check_warn "Elasticsearch cluster: YELLOW (attendu en single-node, pas de réplicas)"
    else
        check_fail "Elasticsearch cluster: $ES_STATUS"
    fi
else
    check_fail "Elasticsearch pod: non Running"
fi

# PVC Elasticsearch
echo ""
echo "Stockage persistant :"
PVC_STATUS=$(kubectl get pvc elasticsearch-data-elasticsearch-0 \
    -n elk-stack \
    --no-headers 2>/dev/null | awk '{print $2}' || echo "NOT_FOUND")
PVC_STATUS=${PVC_STATUS:-NOT_FOUND}
if [ "$PVC_STATUS" = "Bound" ]; then
    check_pass "PVC Elasticsearch: Bound (5Gi EBS)"
else
    check_fail "PVC Elasticsearch: $PVC_STATUS (attendu: Bound)"
fi

# Kibana
echo ""
echo "Kibana :"
KIBANA_PODS=$(kubectl get pods -n elk-stack -l app=kibana --no-headers 2>/dev/null || true)
KIBANA_RUNNING=$(count_running "$KIBANA_PODS")
if [ "$KIBANA_RUNNING" -ge 1 ]; then
    check_pass "Kibana pod: Running"
else
    check_fail "Kibana pod: non Running"
fi

# LoadBalancer Kibana
echo ""
echo "LoadBalancer Kibana :"
KIBANA_LB=$(kubectl get svc kibana-svc -n elk-stack \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
KIBANA_LB=${KIBANA_LB:-}
if [ -n "$KIBANA_LB" ] && [ "$KIBANA_LB" != "null" ]; then
    check_pass "LoadBalancer provisionné: $KIBANA_LB"
    echo "  URL Kibana: http://$KIBANA_LB:5601"
else
    check_fail "LoadBalancer non provisionné (EXTERNAL-IP pending)"
fi

# ============================================================
# RÉSUMÉ FINAL
# ============================================================
section "RÉSUMÉ FINAL"
echo ""
TOTAL=$((PASS + FAIL + WARN))
echo "  OK       : $PASS/$TOTAL"
echo "  KO       : $FAIL/$TOTAL"
echo "  Attention: $WARN/$TOTAL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo "  Infrastructure complètement opérationnelle."
elif [ "$FAIL" -eq 0 ]; then
    echo "  Infrastructure opérationnelle avec $WARN avertissement(s)."
else
    echo "  $FAIL problème(s) détecté(s) - intervention requise."
fi

echo ""
echo "Validation terminée: $(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "${HOME}/logs/infoline"
echo "$(date +%Y-%m-%d_%H:%M:%S) - Validation: PASS=$PASS FAIL=$FAIL WARN=$WARN" \
    >> "${HOME}/logs/infoline/validation.log"