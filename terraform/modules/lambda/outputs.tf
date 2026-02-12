output "lambda_function_name" {
  description = "Nom de la fonction Lambda"
  value       = aws_lambda_function.auth.function_name
}

output "lambda_function_arn" {
  description = "ARN de la fonction Lambda"
  value       = aws_lambda_function.auth.arn
}

output "lambda_function_url" {
  description = "URL publique de la fonction Lambda"
  value       = aws_lambda_function_url.auth.function_url
}

output "lambda_role_arn" {
  description = "ARN du rôle IAM Lambda"
  value       = aws_iam_role.lambda.arn
}
