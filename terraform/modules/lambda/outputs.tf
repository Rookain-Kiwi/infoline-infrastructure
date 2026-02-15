# ==============================================================================
# OUTPUTS - Module Lambda
# ==============================================================================
# Expose les attributs de la fonction d'authentification serverless.
# Utilisés par :
#   - Le frontend Angular (lambda_function_url pour les appels auth)
#   - Les scripts de validation (lambda_function_name pour aws lambda invoke)
#   - Le monitoring CloudWatch (lambda_function_arn pour les métriques)
# ==============================================================================

# Nom court de la fonction — utilisé dans les commandes CLI de test et
# de validation de l'infrastructure
output "lambda_function_name" {
  description = "Nom de la fonction Lambda d'authentification"
  value       = aws_lambda_function.auth.function_name
}

# ARN complet de la fonction — format :
# arn:aws:lambda:eu-west-3:<account_id>:function:<function_name>
# Référencé pour les permissions de déclenchement (triggers),
# les politiques IAM et les alertes CloudWatch.
output "lambda_function_arn" {
  description = "ARN de la fonction Lambda"
  value       = aws_lambda_function.auth.arn
}

# URL HTTPS publique générée par AWS Function URL — format :
#   https://<unique_id>.lambda-url.eu-west-3.on.aws/
# Point d'entrée pour les appels d'authentification depuis le frontend.
#
# Note : invocation navigateur bloquée par SCP du compte AWS Free Tier.
# Endpoint validé via CLI (aws lambda invoke) — voir scripts/validate-infra.sh.
output "lambda_function_url" {
  description = "URL HTTPS publique de la fonction Lambda (Function URL)"
  value       = aws_lambda_function_url.auth.function_url
}

# ARN du rôle IAM assumé par Lambda à chaque invocation.
# Exporté pour permettre l'ajout de permissions supplémentaires
# depuis le module racine sans modifier le module Lambda directement.
output "lambda_role_arn" {
  description = "ARN du rôle IAM de la fonction Lambda"
  value       = aws_iam_role.lambda.arn
}