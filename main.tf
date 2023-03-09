provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      tyndallray-tf = "serverless-microservice"
    }
  }
  profile = "tyndallray"
}

data "archive_file" "get_lambda" {
  type        = "zip"
  source_file = "${path.module}/functions/get.js"
  output_path = "${path.module}/functions/get.zip"
}

resource "aws_s3_bucket" "code_bucket" {
  bucket = "tf-code-bucket-tyndallray"
}

resource "aws_s3_object" "get_lambda_zip" {
  bucket = aws_s3_bucket.code_bucket.id
  key    = "get.zip"
  source = data.archive_file.get_lambda.output_path
	source_hash = data.archive_file.get_lambda.output_base64sha256
}

resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "tf-serverless-microservice"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "api_gateway_log_group" {
  name              = "/aws/api-gateway-log-group/${aws_apigatewayv2_api.api_gateway.name}"
  retention_in_days = 7
}

resource "aws_apigatewayv2_stage" "api_gateway_stage_v1" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "tf-stage-v1"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_log_group.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "api_gateway_get_lambda_proxy" {
  api_id = aws_apigatewayv2_api.api_gateway.id

  integration_uri    = aws_lambda_function.get_lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "api_gateway_get_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /tf-message"
  target    = "integrations/${aws_apigatewayv2_integration.api_gateway_get_lambda_proxy.id}"
}

resource "aws_lambda_permission" "api_gateway_get_lambda_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_function" "get_lambda" {
  function_name    = "tf-get-lambda"
  s3_bucket        = aws_s3_bucket.code_bucket.id
  s3_key           = aws_s3_object.get_lambda_zip.key
  runtime          = "nodejs16.x"
  handler          = "get.main"
  source_code_hash = data.archive_file.get_lambda.output_base64sha256
  role             = aws_iam_role.get_lambda_role.arn
}

resource "aws_cloudwatch_log_group" "get_lambda_log_group" {
  name = "/aws/lambda/${aws_lambda_function.get_lambda.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "get_lambda_role" {
  name = "tf-get-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "get_lambda_policy" {
  role       = aws_iam_role.get_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
