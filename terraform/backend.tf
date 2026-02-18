resource "aws_instance" "backend" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name
  
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y openjdk-17-jdk maven git
              
              mkdir -p /opt/open-invite
              chown -R ubuntu:ubuntu /opt/open-invite
              
              cat > /etc/systemd/system/open-invite.service <<'SERVICE'
[Unit]
Description=Open Invite Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/open-invite
ExecStart=/usr/bin/java -jar /opt/open-invite/backend.jar
Restart=on-failure
RestartSec=10
Environment="SPRING_PROFILES_ACTIVE=production"

[Install]
WantedBy=multi-user.target
SERVICE
              
              systemctl daemon-reload
              systemctl enable open-invite
              EOF
  
  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
    Type = "Backend"
  }
}
