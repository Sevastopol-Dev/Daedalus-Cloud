# TEST ENVIRONMENT: 2-Tier VPC Setup for LocalStack

resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "daedalus-test-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "daedalus-igw"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "daedalus-public-subnet-1"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "daedalus-private-subnet-1"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "daedalus-public-rt"
  }
}

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

# DECEPTION MODULE INSTANTIATION

module "daedalus_deception" {
  source = "../modules/daedalus_core"

  environment        = var.environment
  enable_cloudtrail  = var.enable_cloudtrail
  vpc_id             = aws_vpc.test_vpc.id
  private_subnet_ids = [aws_subnet.private_1.id]
}
