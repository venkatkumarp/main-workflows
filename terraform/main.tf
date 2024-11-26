# Clone both repositories
resource "null_resource" "clone_repositories" {
  provisioner "local-exec" {
    command = <<EOT
      git clone https://github.com/your-org/app-repo.git /tmp/app-repo
      git clone https://github.com/your-org/infra-repo.git /tmp/infra-repo
    EOT
  }
}

# Merge code from both repositories (if necessary)
resource "null_resource" "merge_lambda_code" {
  depends_on = [null_resource.clone_repositories]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p /tmp/lambda-code
      cp -r /tmp/app-repo/* /tmp/lambda-code/
      cp -r /tmp/infra-repo/* /tmp/lambda-code/
    EOT
  }
}

# Create a zip file of the Lambda code
data "archive_file" "lambda_zip" {
  depends_on = [null_resource.merge_lambda_code]

  type        = "zip"
  source_dir  = "/tmp/lambda-code"   # Ensure this points to the correct directory
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
