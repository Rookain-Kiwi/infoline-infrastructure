# kubernetes/elk-stack/

Stack de supervision InfoLine déployée sur EKS dans le namespace `elk-stack`.
Compose Elasticsearch (stockage et indexation des logs) et Kibana (visualisation).

## Architecture

```
Pods applicatifs (backend, frontend)
        │
        │  logs (kubectl exec / Filebeat à venir)
        ▼
┌─────────────────────────────────────────────┐
│  Namespace : elk-stack                      │
│                                             │
│  StatefulSet elasticsearch                  │
│  ├── InitContainer fix-permissions          │
│  ├── PersistentVolume 5Gi (EBS gp2)         │
│  └── Service ClusterIP :9200 / :9300        │
│                                             │
│  Deployment kibana                          │
│  ├── ConfigMap kibana-config                │
│  └── Service LoadBalancer :5601             │
│        │                                    │
└────────┼────────────────────────────────────┘
         │
   ELB AWS (EXTERNAL-IP)
   http://<elb-url>:5601
```

## Contenu du dossier

```
elk-stack/
├── namespace/
│   └── elk-stack-namespace.yaml
├── elasticsearch/
│   ├── elasticsearch-statefulset.yaml  # StatefulSet single-node + InitContainer
│   ├── elasticsearch-service.yaml      # ClusterIP :9200 (REST) + :9300 (transport)
│   └── elasticsearch-pvc.yaml          # PVC 5Gi EBS gp2 (optionnel — géré par volumeClaimTemplates)
└── kibana/
    ├── kibana-configmap.yaml            # kibana.yml (connexion Elasticsearch)
    ├── kibana-deployment.yaml           # Deployment + variables d'environnement
    └── kibana-service.yaml             # LoadBalancer AWS :5601
```

## Déploiement

### Prérequis

- Cluster EKS opérationnel (`kubectl get nodes`)
- EBS CSI Driver installé (`kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver`)

### Ordre d'application

```bash
# 1. Namespace
kubectl create namespace elk-stack

# 2. Elasticsearch (StatefulSet + Service)
kubectl apply -f elasticsearch/elasticsearch-statefulset.yaml
kubectl apply -f elasticsearch/elasticsearch-service.yaml

# 3. Attendre qu'Elasticsearch soit Ready avant de déployer Kibana
kubectl wait --for=condition=ready pod/elasticsearch-0 -n elk-stack --timeout=120s

# 4. Kibana (ConfigMap → Deployment → Service)
kubectl apply -f kibana/kibana-configmap.yaml
kubectl apply -f kibana/kibana-deployment.yaml
kubectl apply -f kibana/kibana-service.yaml
```

L'ordre est important : Kibana tente de se connecter à Elasticsearch au démarrage.
Si Elasticsearch n'est pas encore prêt, Kibana redémarre en boucle (CrashLoopBackOff).

### Vérification

```bash
# État des pods
kubectl get pods -n elk-stack

# Santé du cluster Elasticsearch
kubectl exec -n elk-stack elasticsearch-0 -- curl -s http://localhost:9200/_cluster/health

# URL Kibana (attendre ~60s après le déploiement)
kubectl get svc kibana-svc -n elk-stack
```

### Accès à Kibana

```bash
# Récupérer l'URL du LoadBalancer
KIBANA_URL=$(kubectl get svc kibana-svc -n elk-stack \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "http://$KIBANA_URL:5601"
```

## Indexation de logs

### Insérer des logs de test

```bash
# Log INFO
kubectl exec -n elk-stack elasticsearch-0 -- curl -s -X POST \
  "http://localhost:9200/app-logs/_doc" \
  -H "Content-Type: application/json" \
  -d '{"@timestamp":"2026-02-10T10:00:00","level":"INFO","service":"backend","message":"Application started"}'

# Log ERROR
kubectl exec -n elk-stack elasticsearch-0 -- curl -s -X POST \
  "http://localhost:9200/app-logs/_doc" \
  -H "Content-Type: application/json" \
  -d '{"@timestamp":"2026-02-10T10:05:00","level":"ERROR","service":"backend","message":"Database connection failed"}'
```

### Créer la Data View dans Kibana

1. Ouvrir Kibana → **Management** → **Data Views**
2. Créer une Data View : pattern `app-logs*`, champ timestamp `@timestamp`

## Requêtes KQL (Kibana Query Language)

Une fois la Data View créée, dans **Discover** :

| Requête KQL                              | Résultat                                    |
|------------------------------------------|---------------------------------------------|
| `level: "ERROR"`                         | Tous les logs de niveau ERROR               |
| `level: "INFO"`                          | Tous les logs de niveau INFO                |
| `service: "backend"`                     | Logs du service backend uniquement          |
| `service: "frontend"`                    | Logs du service frontend uniquement         |
| `service: "backend" AND level: "ERROR"`  | Erreurs du backend uniquement               |
| `message: "Database*"`                   | Logs dont le message commence par Database  |

## Notes

**Elasticsearch en mode single-node** — suffisant pour un environnement de développement.
Le cluster health est `GREEN` (aucun réplica à assigner). En production, il vaudra mieux
déployer un cluster multi-nœuds pour la haute disponibilité.

**Sécurité xpack désactivée** — simplifie la configuration en dev.
En production, activer `xpack.security.enabled: true` et penser à configurer TLS.

**PVC et cycle destroy/recreate** — le PersistentVolume EBS est supprimé lors
du `terraform destroy` journalier. Les logs insérés ne persistent pas entre les sessions.