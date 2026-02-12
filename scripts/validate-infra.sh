#!/bin/bash

# === Configuration ===
PROJECT_ROOT="${HOME}/GIT/infoline-infrastructure"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
REGION="eu-west-3"
CLUSTER_NAME="infoline-eks-cluster"

# === Compteurs ===
PASS=0
FAIL=0
WARN=0

# === Fonctions ===
check_pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
check_fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
check_warn() { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }
section() { echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo "📋 $1"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

echo "╔════════════════════════════════════════╗"
echo "║   VALIDATION INFRASTRUCTURE INFOLINE  ║"
echo "╚════════════════════════════════════════╝"
echo "📅 Date: $(date '+%Y-%m-%d %H:%M:%S')"

# ============================================================
# PHASE 1 : INFRASTRUCTURE AWS / TERRAFORM
# ============================================================
section "PHASE 1 : INFRASTRUCTURE AWS"

# 1.1 Nodes EKS
echo ""
echo "🖥️  Nodes EKS :"
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
NODE_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
if [ "$NODE_READY" -ge 2 ]; then
    check_pass "$NODE_READY nodes Ready"
else
    check_fail "Seulement $NODE_READY nodes Ready (attendu: 2)"
fi

# Vérifier type t3.medium
INSTANCE_TYPE=$(aws ec2 describe-instances --region $REGION \
    --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" \
    "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceType' \
    --output text 2>/dev/null)
if [ "$INSTANCE_TYPE" = "t3.medium" ]; then
    check_pass "Instance type: t3.medium ✓"
else
    check_fail "Instance type: $INSTANCE_TYPE (attendu: t3.medium)"
fi

# 1.2 Namespaces
echo ""
echo "📦 Namespaces Kubernetes :"
for NS in elk-stack infoline-backend infoline-frontend; do
    if kubectl get namespace $NS &>/dev/null; then
        check_pass "Namespace $NS existe"
    else
        check_fail "Namespace $NS manquant"
    fi
done

# 1.3 EBS CSI Driver
echo ""
echo "💾 EBS CSI Driver :"
EBS_RUNNING=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver \
    --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null); FRONTEND_RUNNING=${FRONTEND_RUNNING:-0}
if [ "$EBS_RUNNING" -ge 4 ]; then
    check_pass "EBS CSI Driver: $EBS_RUNNING pods Running"
else
    check_fail "EBS CSI Driver: seulement $EBS_RUNNING pods Running (attendu: ≥4)"
fi

# 1.4 RDS PostgreSQL
echo ""
echo "🗄️  RDS PostgreSQL :"
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier infoline-dev-postgres \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$RDS_STATUS" = "available" ]; then
    check_pass "RDS PostgreSQL: available"
else
    check_fail "RDS PostgreSQL: $RDS_STATUS (attendu: available)"
fi

# 1.5 ECR Repositories
echo ""
echo "🐳 ECR Repositories :"
for REPO in infoline-backend infoline-frontend; do
    REPO_EXISTS=$(aws ecr describe-repositories \
        --region $REGION \
        --repository-names $REPO \
        --query 'repositories[0].repositoryName' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    if [ "$REPO_EXISTS" = "$REPO" ]; then
        # Vérifier qu'il y a des images
        IMAGE_COUNT=$(aws ecr list-images \
            --region $REGION \
            --repository-name $REPO \
            --query 'imageIds | length(@)' \
            --output text 2>/dev/null || echo "0")
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            check_pass "ECR $REPO: existe ($IMAGE_COUNT images)"
        else
            check_warn "ECR $REPO: existe mais VIDE (pipeline non lancé?)"
        fi
    else
        check_fail "ECR $REPO: manquant"
    fi
done

# 1.6 IAM Roles
echo ""
echo "🔐 IAM Roles :"
for ROLE in infoline-eks-cluster-cluster-role infoline-eks-cluster-node-role infoline-eks-cluster-ebs-csi-driver; do
    if aws iam get-role --role-name $ROLE &>/dev/null; then
        check_pass "IAM Role $ROLE existe"
    else
        check_fail "IAM Role $ROLE manquant"
    fi
done

# 1.7 Mémoire nodes
echo ""
echo "📊 Utilisation mémoire nodes :"
MEMORY_INFO=$(kubectl describe nodes 2>/dev/null | grep -A 3 "Allocated resources" | grep memory | head -2)
echo "  ℹ️  $MEMORY_INFO"

# ============================================================
# PHASE 2 : APPLICATIONS CI/CD
# ============================================================
section "PHASE 2 : APPLICATIONS CI/CD"

# 2.1 Backend
echo ""
echo "☕ Backend Spring Boot :"
BACKEND_RUNNING=$(kubectl get pods -n infoline-backend \
    --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null); FRONTEND_RUNNING=${FRONTEND_RUNNING:-0}
if [ "$BACKEND_RUNNING" -ge 1 ]; then
    check_pass "Backend: $BACKEND_RUNNING pod(s) Running"
else
    check_fail "Backend: aucun pod Running"
fi

BACKEND_SVC=$(kubectl get svc -n infoline-backend \
    --no-headers 2>/dev/null | wc -l)
if [ "$BACKEND_SVC" -ge 1 ]; then
    check_pass "Backend service: existe"
else
    check_warn "Backend service: non trouvé"
fi

# 2.2 Frontend
echo ""
echo "🅰️  Frontend Angular :"
FRONTEND_RUNNING=$(kubectl get pods -n infoline-frontend \
    --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null); FRONTEND_RUNNING=${FRONTEND_RUNNING:-0}
if [ "$FRONTEND_RUNNING" -ge 1 ]; then
    check_pass "Frontend: $FRONTEND_RUNNING pod(s) Running"
else
    check_fail "Frontend: aucun pod Running"
fi

FRONTEND_SVC=$(kubectl get svc -n infoline-frontend \
    --no-headers 2>/dev/null | wc -l)
if [ "$FRONTEND_SVC" -ge 1 ]; then
    check_pass "Frontend service: existe"
else
    check_warn "Frontend service: non trouvé"
fi

# 2.3 Images ECR récentes
echo ""
echo "🐳 Images Docker ECR :"
for REPO in infoline-backend infoline-frontend; do
    LATEST_TAG=$(aws ecr describe-images \
        --region $REGION \
        --repository-name $REPO \
        --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags[0]' \
        --output text 2>/dev/null || echo "none")
    if [ "$LATEST_TAG" != "none" ] && [ "$LATEST_TAG" != "None" ]; then
        check_pass "$REPO dernière image: ${LATEST_TAG:0:12}..."
    else
        check_warn "$REPO: aucune image (pipeline non lancé?)"
    fi
done

# ============================================================
# PHASE 3 : ELK STACK SUPERVISION
# ============================================================
section "PHASE 3 : ELK STACK SUPERVISION"

# 3.1 Elasticsearch
echo ""
echo "🔍 Elasticsearch :"
ES_POD=$(kubectl get pods -n elk-stack -l app=elasticsearch \
    --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null); FRONTEND_RUNNING=${FRONTEND_RUNNING:-0}
if [ "$ES_POD" -ge 1 ]; then
    check_pass "Elasticsearch pod: Running"

    # Tester l'API
    ES_STATUS=$(kubectl exec -n elk-stack elasticsearch-0 -- \
        curl -s http://localhost:9200/_cluster/health \
        --max-time 5 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    if [ "$ES_STATUS" = "green" ]; then
        check_pass "Elasticsearch cluster: GREEN ✓"
    elif [ "$ES_STATUS" = "yellow" ]; then
        check_warn "Elasticsearch cluster: YELLOW (normal pour 1 nœud)"
    else
        check_fail "Elasticsearch cluster: $ES_STATUS"
    fi
else
    check_fail "Elasticsearch pod: non Running"
fi

# 3.2 PVC Elasticsearch
echo ""
echo "💾 Stockage persistant :"
PVC_STATUS=$(kubectl get pvc elasticsearch-data-elasticsearch-0 \
    -n elk-stack \
    --no-headers 2>/dev/null | awk '{print $2}' || echo "NOT_FOUND")
if [ "$PVC_STATUS" = "Bound" ]; then
    check_pass "PVC Elasticsearch: Bound (5Gi)"
else
    check_fail "PVC Elasticsearch: $PVC_STATUS (attendu: Bound)"
fi

# 3.3 Kibana
echo ""
echo "📊 Kibana :"
KIBANA_POD=$(kubectl get pods -n elk-stack -l app=kibana \
    --no-headers 2>/dev/null | grep -c "Running" 2>/dev/null); FRONTEND_RUNNING=${FRONTEND_RUNNING:-0}
if [ "$KIBANA_POD" -ge 1 ]; then
    check_pass "Kibana pod: Running"
else
    check_fail "Kibana pod: non Running"
fi

# 3.4 LoadBalancer Kibana
echo ""
echo "🌐 LoadBalancer Kibana :"
KIBANA_LB=$(kubectl get svc kibana-svc -n elk-stack \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
if [ -n "$KIBANA_LB" ] && [ "$KIBANA_LB" != "null" ]; then
    check_pass "LoadBalancer: $KIBANA_LB"
    echo "  🔗 URL Kibana: http://$KIBANA_LB:5601"
else
    check_fail "LoadBalancer: non provisionné (EXTERNAL-IP pending)"
fi

# ============================================================
# RÉSUMÉ FINAL
# ============================================================
section "RÉSUMÉ FINAL"
echo ""
TOTAL=$((PASS + FAIL + WARN))
echo "  ✅ Réussi  : $PASS/$TOTAL"
echo "  ❌ Échoué  : $FAIL/$TOTAL"
echo "  ⚠️  Attention: $WARN/$TOTAL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo "🎉 INFRASTRUCTURE COMPLÈTEMENT OPÉRATIONNELLE !"
    echo "   Prêt pour la documentation ECF."
elif [ "$FAIL" -eq 0 ]; then
    echo "✅ Infrastructure opérationnelle avec $WARN avertissement(s)"
    echo "   Vérifiez les points signalés ⚠️"
else
    echo "❌ $FAIL problème(s) détecté(s) - intervention requise"
fi

echo ""
echo "📅 Validation terminée: $(date '+%Y-%m-%d %H:%M:%S')"

# Log
mkdir -p "${HOME}/logs/infoline"
echo "$(date +%Y-%m-%d_%H:%M:%S) - Validation: PASS=$PASS FAIL=$FAIL WARN=$WARN" \
    >> "${HOME}/logs/infoline/validation.log"