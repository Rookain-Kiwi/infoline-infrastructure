# ============================================================
# Module Lambda - Service d'authentification InfoLine
# Serverless function pour la gestion des utilisateurs
# ============================================================

# Archive ZIP de la fonction Lambda
data "archive_file" "auth" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda-functions/auth"
  output_path = "${path.module}/../../lambda-functions/auth.zip"
}

# IAM Role pour Lambda
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

# Policy de base pour Lambda (logs CloudWatch)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Fonction Lambda d'authentification
resource "aws_lambda_function" "auth" {
  function_name    = "${var.project_name}-auth"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.auth.output_path
  source_code_hash = data.archive_file.auth.output_base64sha256

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      PROJECT     = var.project_name
      ENVIRONMENT = var.environment
    }
  }

  tags = var.tags
}

# CloudWatch Log Group pour les logs Lambda
resource "aws_cloudwatch_log_group" "lambda_auth" {
  name              = "/aws/lambda/${aws_lambda_function.auth.function_name}"
  retention_in_days = 7

  tags = var.tags
}

# URL publique pour la fonction Lambda (Function URL)
resource "aws_lambda_function_url" "auth" {
  function_name      = aws_lambda_function.auth.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 300
  }
}
