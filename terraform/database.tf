resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  
  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  }
}

resource "aws_db_instance" "postgresql" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "postgres"
  engine_version = "14.21"
  
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  
  publicly_accessible = false
  skip_final_snapshot = true
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-database"
    Type = "Database"
  }
}
