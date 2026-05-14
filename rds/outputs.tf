output "db_endpoint" {
  description = "RDS instance endpoint hostname. Equivalent to CFN export routebox-<env>-db-endpoint."
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS instance port. Equivalent to CFN export routebox-<env>-db-port."
  value       = aws_db_instance.main.port
}

output "db_instance_identifier" {
  description = "RDS instance identifier. Equivalent to CFN export routebox-<env>-db-id."
  value       = aws_db_instance.main.identifier
}
