provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_route53_zone" "main" {
  name    = var.domain_name
  comment = "Managed by Terraform (Global)"
}
