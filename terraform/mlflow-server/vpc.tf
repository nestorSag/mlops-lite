resource "aws_vpc" "mlops_vpc" {
  cidr_block           = var.cidr
  tags                 = local.tags
  enable_dns_support   = true
  enable_dns_hostnames = true
}


resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidr_a
  availability_zone = var.zone_a
  tags              = local.tags
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidr_b
  availability_zone = var.zone_b
  tags              = local.tags
}


resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidr_a
  availability_zone = var.zone_a
  tags              = local.tags
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidr_b
  availability_zone = var.zone_b
  tags              = local.tags
}


resource "aws_subnet" "db_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_cidr_a
  availability_zone = "eu-central-1a"
  tags              = local.tags
}

resource "aws_subnet" "db_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_cidr_b
  availability_zone = "eu-central-1b"
  tags              = local.tags
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.app_name}-${var.env}-db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_a.id, aws_subnet.db_subnet_b.id]
  tags       = local.tags
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = local.tags
}

resource "aws_eip" "nat_ip_a" {
  domain   = "vpc"
  tags = local.tags
}

resource "aws_eip" "nat_ip_b" {
  domain   = "vpc"
  tags = local.tags
}

resource "aws_nat_gateway" "mlflow_nat_a" {
  allocation_id = aws_eip.nat_ip_a.id
  subnet_id     = aws_subnet.public_subnet_a.id

  depends_on = [aws_internet_gateway.main]

  tags = local.tags
}

resource "aws_nat_gateway" "mlflow_nat_b" {
  allocation_id = aws_eip.nat_ip_b.id
  subnet_id     = aws_subnet.public_subnet_b.id

  depends_on = [aws_internet_gateway.main]

  tags = local.tags
}