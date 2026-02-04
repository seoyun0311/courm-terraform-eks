output "api_endpoint" {
  description = "API Gateway 호출 URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}
