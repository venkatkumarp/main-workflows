# Define required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.5.0"

  # Backend configuration (S3)
  backend "s3" {
    bucket = "databuc347"    # Replace with your S3 bucket name
    key    = "test/terraform.tfstate"      # Path inside the bucket for the state file
    region = "us-east-1"                      # Specify your AWS region

    # Optional DynamoDB state locking
    # dynamodb_table = "terraform-state-lock"   # Uncomment if using DynamoDB for state locking
  }
}

# Configure AWS provider
provider "aws" {
  region = "us-east-1" # Specify your AWS region
}

# Variable for repository details
variable "repo_base_url" {
  description = "Base URL of the GitHub repository"
  type        = string
  default     = "https://raw.githubusercontent.com/venkatkumarp/main-web/main/lambda_code" # Path to the lambda_code folder
}

# Fetch Lambda code files directly
resource "null_resource" "fetch_lambda_code" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.module}/lambda_code
      curl -o ${path.module}/lambda_code/index.js ${var.repo_base_url}/index.js
    EOT
  }
}

# Create a ZIP archive for the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_code"  # Entire folder will be zipped
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

# Create the Lambda function
resource "aws_lambda_function" "example_lambda" {
  function_name = "example-lambda"
  role          = aws_iam_role.lambda_execution_role.arn # IAM role for Lambda execution
  handler       = "index.handler" # Entry point to the Lambda function (index.js, handler function)
  runtime       = "nodejs18.x" # Runtime environment for the Lambda function

  # Path to the zipped Lambda function file
  filename = data.archive_file.lambda_zip.output_path

  # Timeout and memory settings (optional)
  timeout      = 15
  memory_size  = 128
}
