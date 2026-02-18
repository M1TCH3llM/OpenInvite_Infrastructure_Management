output "frontend_public_ip" {
  description = "Public IP of frontend server"
  value       = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  description = "Public IP of backend server"
  value       = aws_instance.backend.public_ip
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.postgresql.endpoint
}

output "database_address" {
  description = "Database address"
  value       = aws_db_instance.postgresql.address
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_instance.backend.public_ip}:8080"
}

output "ssh_frontend" {
  description = "SSH command for frontend"
  value       = "ssh -i ~/.ssh/${var.key_name} ubuntu@${aws_instance.frontend.public_ip}"
}

output "ssh_backend" {
  description = "SSH command for backend"
  value       = "ssh -i ~/.ssh/${var.key_name} ubuntu@${aws_instance.backend.public_ip}"
}
