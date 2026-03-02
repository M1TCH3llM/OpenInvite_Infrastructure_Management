output "frontend_public_ip" {
  description = "Public IP of frontend server"
  value       = aws_instance.frontend.public_ip
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
  value       = "http://${aws_lb.backend_alb.dns_name}"
  description = "Backend API URL (via Load Balancer)"
}

output "ssh_frontend" {
  description = "SSH command for frontend"
  value       = "ssh -i ~/.ssh/${var.key_name} ubuntu@${aws_instance.frontend.public_ip}"
}

output "ssh_backend_1" {
  value       = "ssh -i ~/.ssh/${var.key_name} ubuntu@${aws_instance.backend[0].public_ip}"
  description = "SSH command for backend instance 1"
}

output "ssh_backend_2" {
  value       = length(aws_instance.backend) > 1 ? "ssh -i ~/.ssh/${var.key_name} ubuntu@${aws_instance.backend[1].public_ip}" : "Only one backend instance exists"
  description = "SSH command for backend instance 2"
}
