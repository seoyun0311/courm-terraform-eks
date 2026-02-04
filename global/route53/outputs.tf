output "zone_id" {
  value       = aws_route53_zone.main.zone_id
  description = "The Zone ID of the main domain"
}

output "name_servers" {
  value       = aws_route53_zone.main.name_servers
  description = "Name servers to update in your domain registrar"
}

output "domain_name" {
  value       = var.domain_name
  description = "The domain name"
}
