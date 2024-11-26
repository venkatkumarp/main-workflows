# Clone the main-web repository (this contains the lambda_code folder)
resource "null_resource" "clone_main_web_repository" {
  provisioner "local-exec" {
    command = <<EOT
      # Clone the repository to a temp folder
      git clone https://x-access-token:${var.GITHUB_TOKEN}@github.com/venkatkumarp/main-web.git /tmp/main-web
      #git clone https://${var.GITHUB_TOKEN}:x-oauth-basic@github.com/venkatkumarp/main-web.git /tmp/main-web
    EOT
  }
}

# Ensure lambda_code folder exists after cloning
resource "null_resource" "check_lambda_code" {
  depends_on = [null_resource.clone_main_web_repository]

  provisioner "local-exec" {
    command = <<EOT
      # Verify the lambda_code folder exists
      if [ ! -d "/tmp/main-web/lambda_code" ]; then
        echo "lambda_code directory not found!"
        exit 1
      fi
    EOT
  }
}

# Merge code from the cloned main-web repository into the lambda_code directory
resource "null_resource" "merge_lambda_code" {
  depends_on = [null_resource.check_lambda_code]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p /tmp/lambda-code
      cp -r /tmp/main-web/lambda_code/* /tmp/lambda-code/
    EOT
  }
}

# Create a zip file of the Lambda code from the lambda_code directory
data "archive_file" "lambda_zip" {
  depends_on = [null_resource.merge_lambda_code]

  type        = "zip"
  source_dir  = "/tmp/lambda-code"   # Ensure this points to the lambda_code directory
  output_path = "/tmp/lambda-code.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Sid       = ""
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

variable "GITHUB_TOKEN" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
  default = "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"
}
