resource "random_password" "db_password" {
  length  = 16
  special = false
}

# RDS subnet group uses PRIVATE subnets — the database has no internet route.
# EKS nodes can still reach it because they share the same VPC.
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.cluster_name}-rds-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS PostgreSQL - allows Postgres from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Postgres traffic from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_nodes_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.cluster_name}-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t4g.micro" # Free Tier eligible
  allocated_storage = 20
  storage_type      = "gp3"
  db_name           = "acmecorp"
  username          = "postgres"
  password          = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Protects against accidental `terraform destroy` in production.
  # Set deletion_protection = true in prod.tfvars.
  deletion_protection = var.deletion_protection
  skip_final_snapshot = !var.deletion_protection # Take a snapshot in prod

  # Not publicly accessible — the database is in private subnets
  # and only accepts connections from EKS nodes via SG rule.
  publicly_accessible = false

  tags = {
    Name = "${var.cluster_name}-db"
  }
}
