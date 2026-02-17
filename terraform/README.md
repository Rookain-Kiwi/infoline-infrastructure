# terraform/

Infrastructure as Code du projet InfoLine — déploie l'ensemble des ressources AWS
via 5 modules indépendants orchestrés par `main.tf`.

## Modules

| Module    | Ressources déployées                                              |
|-----------|-------------------------------------------------------------------|
| `vpc`     | VPC, subnets (public/private/database), NAT Gateways, IGW, routes |
| `eks`     | Cluster EKS, node group, IAM roles, OIDC provider, EBS CSI IRSA   |
| `rds`     | Instance PostgreSQL 16, subnet group, parameter group, SG         |
| `ecr`     | Dépôts Docker backend et frontend, lifecycle policies             |
| `lambda`  | Fonction d'authentification Node.js 20.x, Function URL, IAM role  |

### Ordre de déploiement

```
vpc → eks + rds + ecr + lambda (en parallèle)
```

`eks`, `rds` et `lambda` dépendent du VPC. `ecr` est indépendant.
Les dépendances sont gérées par `depends_on` et les références inter-modules dans `main.tf`.

## Choix techniques

### EKS — ON_DEMAND t3.medium

SPOT a été testé mais abandonné pour deux raisons :
- Indisponibilité de capacité SPOT en eu-west-3 sur le compte Free Tier
- Restrictions SCP du compte AWS bloquant SPOT sur certains types d'instances

t3.medium (4GB RAM) est le minimum viable pour ce projet : t3.small provoquait
des OOMKilled sur le pod Elasticsearch (512MB heap JVM + overhead).

### EBS CSI Driver — Helm plutôt qu'en addon EKS managé

L'addon `aws-ebs-csi-driver` via `aws_eks_addon` Terraform provoquait des timeouts
systématiques lors du `terraform apply` (attente infinie de readiness avant que
les nodes soient prêts). Le driver est installé via Helm dans `startup-infra.sh`
après la création du cluster, avec le rôle IRSA provisionné par Terraform.

### Lambda — Function URL sans API Gateway

Plus simple et sans surcoût pour un endpoint unique. L'invocation navigateur étant
bloquée par les SCP du compte AWS Free Tier, l'endpoint est alors validé via CLI :
```bash
aws lambda invoke --function-name infoline-auth --payload '{}' response.json
```

### RDS — sans Multi-AZ, sans backup automatique

Multi-AZ désactivé : réplication synchrone non nécessaire en développement.
`backup_retention_period = 0` dans `terraform.tfvars.example` : les snapshots
automatiques bloquent le `terraform destroy` journalier et s'accumulent.
En production, il faudra penser à mettre `backup_retention_period = 7` 
et `multi_az = true`.

## Configuration

### Prérequis

```bash
cp terraform.tfvars.example terraform.tfvars
# Renseigner db_password — SURTOUT NE JAMAIS COMMITER terraform.tfvars!
```

### Variables principales

| Variable                     | Défaut                  | Description                              |
|------------------------------|-------------------------|------------------------------------------|
| `aws_region`                 | `eu-west-3`             | Région AWS                               |
| `cluster_name`               | `infoline-eks-cluster`  | Nom du cluster EKS                       |
| `cluster_version`            | `1.31`                  | Version Kubernetes                       |
| `node_instance_types`        | `["t3.medium"]`         | Type d'instance worker nodes             |
| `node_desired_size`          | `2`                     | Nombre de nodes souhaité                 |
| `db_password`                | *(requis)*              | Mot de passe PostgreSQL (sensible)       |
| `db_instance_class`          | `db.t3.micro`           | Classe d'instance RDS                    |
| `db_backup_retention_period` | `7`                     | Rétention sauvegardes RDS (jours)        |

Toutes les variables sont documentées dans `variables.tf`.

## Commandes

```bash
# Initialisation
terraform init

# Vérification du plan
terraform plan -out=tfplan

# Déploiement
terraform apply tfplan

# Destruction
terraform destroy -auto-approve

# Afficher les outputs post-déploiement
terraform output
```

## Outputs principaux

| Output                        | Description                                        | Consommé par                    |
|-------------------------------|----------------------------------------------------|---------------------------------|
| `eks_cluster_name`            | Nom du cluster                                     | kubectl, scripts, pipelines     |
| `eks_cluster_endpoint`        | URL API server EKS                                 | provider.tf, kubeconfig         |
| `ebs_csi_driver_role_arn`     | ARN rôle IRSA EBS CSI Driver                       | startup-infra.sh (Helm)         |
| `ecr_backend_repository_url`  | URL ECR backend                                    | CI/CD backend, k8s/deployment   |
| `ecr_frontend_repository_url` | URL ECR frontend                                   | CI/CD frontend, k8s/deployment  |
| `rds_endpoint`                | Endpoint PostgreSQL (host:port)                    | Backend Spring Boot             |
| `rds_connection_string`       | JDBC URL (sans credentials)                        | Secret Kubernetes               |
| `lambda_function_url`         | URL HTTPS Lambda auth                              | Frontend Angular                |
| `lambda_function_name`        | Nom de la fonction                                 | validate-infra.sh               |

## Fichiers sensibles

`terraform.tfvars` contient les credentials de la base de données — il est exclu
du versioning via `.gitignore`. Utiliser `terraform.tfvars.example` comme modèle.

Ne jamais commiter `terraform.tfstate` ni `terraform.tfstate.backup` — ces fichiers
contiennent des valeurs sensibles en clair (endpoints, ARNs, outputs sensibles).