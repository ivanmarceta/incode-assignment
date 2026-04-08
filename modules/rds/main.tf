locals {
  identifier = "${var.name_prefix}-postgres"
}

resource "aws_db_subnet_group" "database" {
  name       = "${local.identifier}-subnets"
  subnet_ids = var.database_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${local.identifier}-subnets"
    }
  )
}

resource "aws_security_group" "database" {
  name        = "${local.identifier}-sg"
  description = "Security group for the PostgreSQL instance."
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow PostgreSQL traffic from the application tier."
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.identifier}-sg"
    }
  )
}

resource "aws_db_instance" "database" {
  identifier                   = local.identifier
  engine                       = var.engine
  engine_version               = var.engine_version
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  db_name                      = var.database_name
  username                     = var.database_username
  port                         = var.port
  db_subnet_group_name         = aws_db_subnet_group.database.name
  vpc_security_group_ids       = [aws_security_group.database.id]
  multi_az                     = var.multi_az
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${local.identifier}-final"
  backup_retention_period      = var.backup_retention_period
  storage_encrypted            = var.storage_encrypted
  manage_master_user_password  = var.manage_master_user_password
  publicly_accessible          = var.publicly_accessible
  auto_minor_version_upgrade   = true
  performance_insights_enabled = var.performance_insights_enabled
  apply_immediately            = true

  tags = merge(
    var.tags,
    {
      Name = local.identifier
    }
  )
}
