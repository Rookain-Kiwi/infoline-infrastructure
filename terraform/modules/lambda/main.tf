# ==============================================================================
# MODULE LAMBDA - Service d'authentification InfoLine
# ==============================================================================
# Implémente l'authentification des utilisateurs en mode serverless.
# Avantages par rapport à un microservice Kubernetes dédié :
#   - Facturation à l'invocation (pas de pod idle en attente)
#   - Scaling automatique sans configuration
#   - Isolation complète du service auth vis-à-vis de l'API backend
#
# Architecture :
#   Frontend Angular → Lambda Function URL (HTTPS publique) → JWT response
#
# Note : Lambda Function URL bloquée par SCP (Service Control Policy) du
# compte AWS Free Tier en invocation HTTP directe depuis le navigateur.
# L'invocation CLI (aws lambda invoke) est validée et fonctionnelle.
# La Function URL reste provisionnée pour la démonstration de l'architecture.
# ==============================================================================

# ------------------------------------------------------------------------------
# Archive ZIP du code source
# ------------------------------------------------------------------------------
# Terraform empaquette le répertoire source en ZIP avant l'upload vers Lambda.
# source_dir  : répertoire contenant index.js et ses dépendances node_modules
# output_path : chemin du ZIP généré (hors du répertoire Terraform)
#
# source_code_hash est calculé depuis ce ZIP — si le code change, Terraform
# détecte la différence et déclenche un nouveau déploiement de la fonction.
# ------------------------------------------------------------------------------
data "archive_file" "auth" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda-functions/auth"
  output_path = "${path.module}/../../lambda-functions/auth.zip"
}

# ------------------------------------------------------------------------------
# IAM Role Lambda
# ------------------------------------------------------------------------------
# Lambda assume ce rôle à chaque invocation pour accéder aux services AWS.
# Trust policy : seul le service lambda.amazonaws.com peut assumer ce rôle.
# Principe du moindre privilège : seules les permissions nécessaires
# sont accordées via les policy attachments ci-dessous.
# ------------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# AWSLambdaBasicExecutionRole : permissions minimales pour qu'une Lambda
# puisse écrire ses logs dans CloudWatch Logs (CreateLogGroup,
# CreateLogStream, PutLogEvents). Sans cette policy, les invocations
# réussissent mais aucun log n'est conservé.
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ------------------------------------------------------------------------------
# Fonction Lambda d'authentification
# ------------------------------------------------------------------------------
# runtime  : nodejs20.x — LTS actif, support AWS jusqu'en 2026
# handler  : "index.handler" → fichier index.js, export de la fonction handler
# timeout  : 30s — largement suffisant pour une opération d'auth JWT
# memory   : 128MB — minimum Lambda, adapté à une fonction auth légère
#            (à augmenter à 256MB si la latence est trop élevée)
#
# source_code_hash : empreinte base64 du ZIP — Terraform compare à chaque
# plan pour détecter les changements de code sans re-uploader inutilement.
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "auth" {
  function_name    = "${var.project_name}-auth"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.auth.output_path
  source_code_hash = data.archive_file.auth.output_base64sha256

  timeout     = 30   # Temps avant timeout forcé par AWS
  memory_size = 128  # Détermine aussi le CPU alloué proportionnellement

  environment {
    variables = {
      PROJECT     = var.project_name  # Utilisé pour le logging et le contexte
      ENVIRONMENT = var.environment   # Permettrait d'adapter le comportement dev/prod
    }
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group
# ------------------------------------------------------------------------------
# Crée explicitement le Log Group avant la première invocation Lambda.
# Sans cette ressource, AWS crée le groupe automatiquement mais sans
# politique de rétention — les logs s'accumulent indéfiniment et génèrent
# des coûts de stockage CloudWatch non maîtrisés.
#
# retention_in_days = 7 : cohérent avec la rétention RDS backup (7 jours)
# et le cycle de vie du projet (destroy/recreate journalier).
# Le nom /aws/lambda/${aws_lambda_function.auth.function_name} est la convention 
# AWS pour Lambda.
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_auth" {
  name              = "/aws/lambda/${aws_lambda_function.auth.function_name}"
  retention_in_days = 7

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Lambda Function URL
# ------------------------------------------------------------------------------
# Expose la fonction via une URL HTTPS publique sans passer par API Gateway.
# Plus simple et moins coûteux qu'API Gateway pour un endpoint unique.
#
# authorization_type = "NONE" : pas d'authentification IAM sur l'URL elle-même
# La sécurité est gérée dans le code de la fonction (validation JWT et
# vérification des credentials).
#
# CORS configuré en mode permissif (allow_origins = ["*"]) pour le dev.
# En production, on devrait restreindre allow_origins au domaine du frontend InfoLine.
#
# Limitation compte AWS Education :
# Les SCP (Service Control Policies) du compte Free Tier bloquent l'invocation
# depuis un navigateur via Function URL. 
# L'invocation CLI est validée :
# aws lambda invoke --function-name infoline-auth --payload '{}' response.json
# La Function URL reste provisionnée pour documenter l'architecture cible.
# ------------------------------------------------------------------------------
resource "aws_lambda_function_url" "auth" {
  function_name      = aws_lambda_function.auth.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]       # À restreindre en production
    allow_methods     = ["*"]       # GET, POST, OPTIONS, etc.
    allow_headers     = ["*"]       # Authorization, Content-Type, etc.
    expose_headers    = ["*"]
    max_age           = 300         # Durée de mise en cache CORS preflight (secondes)
  }
}