# Fetch Lambda code files directly using git
resource "null_resource" "fetch_lambda_code" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${path.module}/lambda_code
      git clone --branch main https://github.com/venkatkumarp/main-web.git ${path.module}/lambda_code
    EOT
  }
}

# Create a ZIP archive for the Lambda function code, but wait for the fetch_lambda_code resource
data "archive_file" "lambda_zip" {
  depends_on = [null_resource.fetch_lambda_code]  # Ensure fetch_lambda_code runs first
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
