# VPC Module - Single-AZ Configuration for Cost Optimization

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "novapay-${var.environment}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "novapay-${var.environment}-igw"
  }
}

# Public Subnet (for ALB and ECS tasks with public IPs)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "novapay-${var.environment}-public-subnet"
    Type = "Public"
  }
}

# Private Subnet (for RDS and Redis) - Primary AZ
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "novapay-${var.environment}-private-subnet"
    Type = "Private"
  }
}

# Public Subnet 2 (for ALB multi-AZ requirement) - Secondary AZ
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "novapay-${var.environment}-public-subnet-2"
    Type = "Public"
  }
}

# Private Subnet 2 (for RDS multi-AZ requirement) - Secondary AZ
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.availability_zone_2

  tags = {
    Name = "novapay-${var.environment}-private-subnet-2"
    Type = "Private"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "novapay-${var.environment}-public-rt"
  }
}

# Route Table Association for Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association for Public Subnet 2
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "novapay-${var.environment}-nat-eip"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Purpose     = "PoC-Learning"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (replacing NAT Instance for reliable internet connectivity)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name        = "novapay-${var.environment}-nat-gateway"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Purpose     = "PoC-Learning"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Private Subnet (with NAT Gateway for outbound internet)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "novapay-${var.environment}-private-rt"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Purpose     = "PoC-Learning"
  }
}

# Route Table Association for Private Subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Route Table Association for Private Subnet 2
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}
