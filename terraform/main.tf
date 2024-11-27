
# Define the AWS provider
provider "aws" {
  region = "us-east-1" # Replace with your desired region
}

# Specify Terraform settings and backend
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.7" # Ensure compatibility with AWS resources
    }
  }
  
  backend "s3" {
    bucket         = "tftest8"
    key            = "path/test/terraform.tfstate" # Path to the state file in the bucket
    region         = "us-east-1" # Replace with your bucket's region
    encrypt        = true        # Encrypt state file at rest (recommended)
    #dynamodb_table = "terraform-lock-table" # Optional: For state locking
  }
}



###########################################
# Data source to fetch the S3 bucket object (zip file)
data "aws_s3_bucket_object" "lambda_zip" {
  bucket = "tftest8"
  key = "test/lambda-function.zip"
}

# Lambda function resource using the S3 zip file
resource "aws_lambda_function" "example_lambda" {
  function_name = "example-lambda-function"
  
  # Use the S3 object as the source
  s3_bucket = data.aws_s3_bucket_object.lambda_function.bucket
  s3_key = data.aws_s3_bucket_object.lambda-function.key
  
  # Alternatively, you can use source_code_hash for change detection
  source_code_hash = data.aws_s3_bucket_object.lambda_function.etag
  
  handler = "index.handler" # Replace with your handler
  runtime = "nodejs18.x" # Replace with your runtime
  
  # IAM role for the Lambda function
  role = aws_iam_role.lambda_role.arn
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "example-lambda-role"

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

# Optional: IAM policy to allow basic Lambda execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role = aws_iam_role.lambda_role.name
}
