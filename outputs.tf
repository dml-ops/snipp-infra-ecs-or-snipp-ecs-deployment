output "app_server_public_ip" {
  value = aws_eip.app_server.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "name_servers" {
  value = var.hosted_zone_id == "" ? aws_route53_zone.primary[0].name_servers : []
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/urlshortener_key ubuntu@${aws_eip.app_server.public_ip}"
}

