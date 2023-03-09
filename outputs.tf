output "code_bucket_name" {
  value = aws_s3_bucket.code_bucket.id
}

output "code_bucket_arn" {
  value = aws_s3_bucket.code_bucket.arn
}

output "stage_url" {
	value = aws_apigatewayv2_stage.api_gateway_stage_v1.invoke_url
}