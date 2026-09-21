resource "aws_security_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL from ECS only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "app" {
  count      = var.enable_rds ? 1 : 0
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

resource "random_password" "db" {
  count   = var.enable_rds ? 1 : 0
  length  = 20
  special = true
}

resource "aws_db_instance" "postgres" {
  count                      = var.enable_rds ? 1 : 0
  identifier                 = "${var.project_name}-postgres"
  engine                     = "postgres"
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  db_name                    = var.db_name
  username                   = var.db_username
  password                   = random_password.db[0].result
  db_subnet_group_name       = aws_db_subnet_group.app[0].name
  vpc_security_group_ids     = [aws_security_group.rds[0].id]
  publicly_accessible        = false
  multi_az                   = false
  storage_encrypted          = true
  backup_retention_period    = 7
  auto_minor_version_upgrade = true
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot
}
