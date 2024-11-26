# Clone the repository with Lambda code
resource "null_resource" "clone_lambda_code" {
  provisioner "local-exec" {
    command = <<EOT
      git clone --branch main https://github.com/venkatkumarp/main-web.git ${path.module}/lambda_code
    EOT
  }
}

# Merge Lambda code (if you want to merge multiple repositories)
# This step is optional and can be used if you need to combine Lambda code from multiple sources.
resource "null_resource" "merge_lambda_code" {
  depends_on = [null_resource.clone_lambda_code]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.module}/lambda_code_merged
      cp -r ${path.module}/lambda_code/* ${path.module}/lambda_code_merged/
      # Optionally, merge from another repo or source here.
    EOT
  }
}

# Create a ZIP file of the Lambda code
data "archive_file" "lambda_zip" {
  depends_on = [null_resource.merge_lambda_code]  # Ensure the merging happens before creating the archive

  type        = "zip"
  source_dir  = "${path.module}/lambda_code_merged"  # The merged code directory
  output_path = "${path.module}/lambda_function.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect    = "Allow"
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
