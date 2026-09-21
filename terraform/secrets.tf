locals {
  db_host_for_secret = var.enable_rds ? aws_db_instance.postgres[0].address : var.db_host_override
  db_port_for_secret = 5432
  db_pass_for_secret = var.enable_rds ? random_password.db[0].result : var.db_password_override
}

resource "aws_secretsmanager_secret" "db" {
  count       = var.enable_secrets ? 1 : 0
  name        = var.db_secret_name
  description = "Database credentials/config for ${var.project_name}"
}

resource "aws_secretsmanager_secret_version" "db" {
  count     = var.enable_secrets ? 1 : 0
  secret_id = aws_secretsmanager_secret.db[0].id
  secret_string = jsonencode({
    username = var.db_username
    password = local.db_pass_for_secret
    host     = local.db_host_for_secret
    port     = local.db_port_for_secret
    dbname   = var.db_name
  })
}
