terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state storage in S3
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "iq-games/terraform.tfstate"
  #   region         = "ap-south-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "iq-games"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Local variables
locals {
  app_name = "iq-games"
  env      = var.environment
  table_prefix = "${local.app_name}-${local.env}"
}

# ============================================
# DynamoDB Tables
# ============================================

# Users table
resource "aws_dynamodb_table" "users" {
  name           = "${local.table_prefix}-users"
  billing_mode   = "PAY_PER_REQUEST"  # Auto-scaling for free tier
  hash_key       = "userId"
  
  attribute {
    name = "userId"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name = "Users Table"
  }
}

# Game scores table
resource "aws_dynamodb_table" "scores" {
  name           = "${local.table_prefix}-scores"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "timestamp"
  
  attribute {
    name = "userId"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "N"
  }
  
  attribute {
    name = "gameId"
    type = "S"
  }

  # Global Secondary Index for querying by game
  global_secondary_index {
    name            = "gameId-timestamp-index"
    hash_key        = "gameId"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name = "Game Scores Table"
  }
}

# Leaderboards table
resource "aws_dynamodb_table" "leaderboards" {
  name           = "${local.table_prefix}-leaderboards"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "gameId"
  range_key      = "score"
  
  attribute {
    name = "gameId"
    type = "S"
  }
  
  attribute {
    name = "score"
    type = "N"
  }
  
  attribute {
    name = "userId"
    type = "S"
  }

  # Global Secondary Index for user lookup
  global_secondary_index {
    name            = "userId-score-index"
    hash_key        = "userId"
    range_key       = "score"
    projection_type = "ALL"
  }

  tags = {
    Name = "Leaderboards Table"
  }
}

# ============================================
# Cognito User Pool (Authentication)
# ============================================

resource "aws_cognito_user_pool" "main" {
  name = "${local.app_name}-${local.env}"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  # Email verification
  email_verification_message = "Your IQ Games verification code is {####}"
  email_verification_subject = "Your IQ Games verification code"

  # Allow email and username
  username_attributes = ["email"]
  auto_verified_attributes = ["email"]

  # Schema
  schema {
    name              = "email"
    attribute_data_type = "String"
    mutable           = true
    required          = true
  }

  schema {
    name              = "name"
    attribute_data_type = "String"
    mutable           = true
  }

  schema {
    name              = "phone_number"
    attribute_data_type = "String"
    mutable           = true
  }

  tags = {
    Name = "IQ Games User Pool"
  }
}

# Cognito User Pool Client (for app)
resource "aws_cognito_user_pool_client" "app" {
  name                = "${local.app_name}-client"
  user_pool_id        = aws_cognito_user_pool.main.id
  generate_secret     = false
  explicit_auth_flows = ["ADMIN_NO_SRP_AUTH", "USER_PASSWORD_AUTH"]

  # Allow signup
  prevent_user_existence_errors = "LEGACY"
}

# ============================================
# S3 Bucket for Game Assets & Backups
# ============================================

resource "aws_s3_bucket" "game_assets" {
  bucket = "${local.table_prefix}-assets-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "game_assets" {
  bucket = aws_s3_bucket.game_assets.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "game_assets" {
  bucket = aws_s3_bucket.game_assets.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Public access block (allow for public game assets if needed)
resource "aws_s3_bucket_public_access_block" "game_assets" {
  bucket = aws_s3_bucket.game_assets.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# ============================================
# IAM Roles for Lambda
# ============================================

resource "aws_iam_role" "lambda_role" {
  name = "${local.app_name}-lambda-role"

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
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB access policy
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${local.app_name}-lambda-dynamodb"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.scores.arn,
          aws_dynamodb_table.leaderboards.arn,
          "${aws_dynamodb_table.scores.arn}/index/*",
          "${aws_dynamodb_table.leaderboards.arn}/index/*"
        ]
      }
    ]
  })
}

# S3 access policy
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${local.app_name}-lambda-s3"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.game_assets.arn}/*"
      }
    ]
  })
}

# ============================================
# Lambda Function for Leaderboard API
# ============================================

resource "aws_lambda_function" "leaderboard_api" {
  filename         = "lambda_function.zip"
  function_name    = "${local.app_name}-leaderboard-api"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      USERS_TABLE       = aws_dynamodb_table.users.name
      SCORES_TABLE      = aws_dynamodb_table.scores.name
      LEADERBOARDS_TABLE = aws_dynamodb_table.leaderboards.name
      ASSETS_BUCKET     = aws_s3_bucket.game_assets.id
      ENVIRONMENT       = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_dynamodb,
    aws_iam_role_policy.lambda_s3
  ]
}

# ============================================
# API Gateway
# ============================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.app_name}-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format         = "$context.requestId $context.error.message $context.error.messageString"
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"
  integration_uri    = aws_lambda_function.leaderboard_api.invoke_arn
}

resource "aws_apigatewayv2_route" "leaderboard" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /leaderboard/{gameId}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.leaderboard_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ============================================
# CloudWatch Logging
# ============================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.app_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.app_name}"
  retention_in_days = 7
}

# ============================================
# CloudWatch Alarms
# ============================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.app_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when Lambda errors exceed threshold"
  dimensions = {
    FunctionName = aws_lambda_function.leaderboard_api.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle" {
  alarm_name          = "${local.app_name}-dynamodb-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ConsumedWriteCapacityUnits"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 80
  alarm_description   = "Alert when DynamoDB write capacity is high"
  dimensions = {
    TableName = aws_dynamodb_table.scores.name
  }
}

# ============================================
# Data Sources
# ============================================

data "aws_caller_identity" "current" {}

# ============================================
# Outputs
# ============================================

output "api_endpoint" {
  value       = aws_apigatewayv2_api.main.api_endpoint
  description = "API Gateway endpoint URL"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.main.id
  description = "Cognito User Pool ID"
}

output "cognito_user_pool_client_id" {
  value       = aws_cognito_user_pool_client.app.id
  description = "Cognito User Pool Client ID"
}

output "dynamodb_users_table" {
  value       = aws_dynamodb_table.users.name
  description = "DynamoDB Users table name"
}

output "dynamodb_scores_table" {
  value       = aws_dynamodb_table.scores.name
  description = "DynamoDB Scores table name"
}

output "dynamodb_leaderboards_table" {
  value       = aws_dynamodb_table.leaderboards.name
  description = "DynamoDB Leaderboards table name"
}

output "s3_assets_bucket" {
  value       = aws_s3_bucket.game_assets.id
  description = "S3 Assets bucket name"
}

output "lambda_function_name" {
  value       = aws_lambda_function.leaderboard_api.function_name
  description = "Lambda function name"
}
