  # 1. API Gateway 생성 (HTTP API 버전)
  resource "aws_apigatewayv2_api" "main" {
    name          = "courm-api"
    protocol_type = "HTTP"
    description   = "Serverless HTTP API for courm"
  }

  # 2. 통합 (Integration) : API Gateway -> ALB 연결
  # ALB가 Public이므로 HTTP_PROXY 방식을 사용하여 인터넷을 통해 연결합니다.
  resource "aws_apigatewayv2_integration" "alb_integration" {
    api_id             = aws_apigatewayv2_api.main.id
    integration_type   = "HTTP_PROXY"
    integration_uri    = "http://${var.alb_dns_name}" # ALB 주소로 바로 토스
    integration_method = "ANY"
  }

  # 3. 라우트 (Route) : 모든 경로(/{proxy+})를 ALB로 보냄
  # 예: /users, /products, /carts 무엇이 오든 다 ALB로 보냄
  resource "aws_apigatewayv2_route" "default_route" {
    api_id    = aws_apigatewayv2_api.main.id
    route_key = "ANY /{proxy+}" # 와일드카드 경로
    target    = "integrations/${aws_apigatewayv2_integration.alb_integration.id}"
  }

  # 4. 스테이지 (Stage) : 배포 환경 설정
  # auto_deploy를 켜서 설정 변경 시 즉시 반영되도록 함
  resource "aws_apigatewayv2_stage" "default" {
    api_id      = aws_apigatewayv2_api.main.id
    name        = "$default"
    auto_deploy = true
  }
