resource "aws_instance" "frontend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx nodejs npm git
              
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt-get install -y nodejs
              
              mkdir -p /var/www/open-invite
              chown -R ubuntu:ubuntu /var/www/open-invite
              
              cat > /etc/nginx/sites-available/default <<'NGINX'
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;
                  
                  root /var/www/open-invite/build;
                  index index.html;
                  
                  server_name _;
                  
                  location / {
                      try_files $uri $uri/ /index.html;
                  }
              }
NGINX
              
              systemctl restart nginx
              systemctl enable nginx
              EOF
  
  tags = {
    Name = "${var.project_name}-${var.environment}-frontend"
    Type = "Frontend"
  }
}
