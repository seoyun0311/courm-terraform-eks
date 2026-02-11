# ==============================================================================
# 1. VPC (Virtual Private Cloud)
# ==============================================================================
  resource "aws_vpc" "this" {
    cidr_block           = var.vpc_cidr
    enable_dns_hostnames = true # rds 접속 시 사용
    enable_dns_support   = true # dns 서버 기능

    tags = {
      Name = "courm-vpc-${var.environment}" # ex - "courm-vpc-dev" (프로젝트명-vpc-환경)
    }
  }

# ==============================================================================
# 2. Internet Gateway (IGW)
# ==============================================================================
  resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id # vpc 위치 지정

    tags = {
      Name = "courm-igw-${var.environment}"
    }
  }

# ==============================================================================
# 3. Subnets
# ==============================================================================

  # (1) Public Subnet: 외부에서 접근 가능한 곳 (ALB, NAT, Bastion 등)
  resource "aws_subnet" "public" {
    count             = length(var.public_subnets)
    vpc_id            = aws_vpc.this.id
    cidr_block        = var.public_subnets[count.index]
    availability_zone = var.azs[count.index]
    map_public_ip_on_launch = true

    tags = {
      Name = "courm-pub-sb-${var.azs[count.index]}"

      # EKS 태그
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/courm-eks-prod" = "shared"
    }
  }

  # (2) App Subnet: ECS 컨테이너가 실행될 곳
  resource "aws_subnet" "app" {
    count             = length(var.app_subnets)
    vpc_id            = aws_vpc.this.id
    cidr_block        = var.app_subnets[count.index]
    availability_zone = var.azs[count.index]

    tags = {
      Name = "courm-pri-app-${var.azs[count.index]}"

      # EKS 태그
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/courm-eks-prod" = "shared"
      
      # Karpenter 태그
      "karpenter.sh/discovery" = "courm-eks-prod"
    }
  }

  # (3) MQ Subnet: Kafka 메시지 큐가 실행될 곳
  resource "aws_subnet" "mq" {
    count             = length(var.mq_subnets) # MQ용 IP 대역 개수만큼 반복
    vpc_id            = aws_vpc.this.id
    cidr_block        = var.mq_subnets[count.index]
    availability_zone = var.azs[count.index]

    tags = {
      Name = "courm-pri-mq-${var.azs[count.index]}"
    }
  }

  # (4) Mgmt Subnet: Jenkins 실행될 곳
  resource "aws_subnet" "mgmt" {
    count             = length(var.mgmt_subnets) # Mgmt용 IP 대역 개수만큼 반복
    vpc_id            = aws_vpc.this.id
    cidr_block        = var.mgmt_subnets[count.index]
    availability_zone = var.azs[count.index]

    tags = {
      Name = "courm-pri-mgmt-${var.azs[count.index]}"
    }
  }

  # (5) Data Subnet: DB, Redis (AZ별 생성) - [수정됨: 끊긴 코드 복구]
  resource "aws_subnet" "data" {
    count = length(var.data_subnets)
    vpc_id            = aws_vpc.this.id
    cidr_block        = var.data_subnets[count.index]
    availability_zone = var.azs[count.index]

    tags = {
      Name = "courm-pri-db-${var.azs[count.index]}"
    }
  }

# ==============================================================================
# 4. NAT Gateway
# ==============================================================================

  # NAT Gateway 하나 필요
  resource "aws_eip" "nat" {
    domain = "vpc"

    tags = {
      Name = "courm-eip-nat-a"
    }
  }

  resource "aws_nat_gateway" "nat" {
    allocation_id = aws_eip.nat.id # 위에서 만든 EIP를 연결
    subnet_id = aws_subnet.public[0].id # 첫번째 Public Subnet에 위치

    tags = {
      Name = "courm-nat-gateway-a"
    }

    # IGW가 생성되어야 통신 가능
    depends_on = [aws_internet_gateway.this]
  }

# ==============================================================================
# 5. Route Tables
# ==============================================================================

  # (1) Public RT (기존 동일)
  resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.this.id
    }
    tags = { Name = "courm-rt-pub" }
  }

  # (2) Private RT
  resource "aws_route_table" "private" {
    count  = length(var.public_subnets) # NAT 개수만큼 생성
    vpc_id = aws_vpc.this.id

    route {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat.id # 각자 맞는 NAT 연결
    }

    tags = {
      Name = "courm-rt-pri-${var.azs[count.index]}"
    }
  }

  # (3) Data RT (기존 동일 - 폐쇄망)
  resource "aws_route_table" "data" {
    vpc_id = aws_vpc.this.id
    tags = { Name = "courm-rt-data" }
  }


# ==============================================================================
# 6. Route Table Associations
# ==============================================================================

  # Public 연결
  resource "aws_route_table_association" "public" {
    count          = length(var.public_subnets)
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
  }

  # App -> Private RT
  resource "aws_route_table_association" "app" {
    count          = length(var.app_subnets)
    subnet_id      = aws_subnet.app[count.index].id
    route_table_id = element(aws_route_table.private[*].id, count.index)
  }

  # MQ -> Private RT
  resource "aws_route_table_association" "mq" {
    count          = length(var.mq_subnets)
    subnet_id      = aws_subnet.mq[count.index].id
    route_table_id = element(aws_route_table.private[*].id, count.index)
  }

  # Mgmt -> Private RT
  resource "aws_route_table_association" "mgmt" {
    count          = length(var.mgmt_subnets)
    subnet_id      = aws_subnet.mgmt[count.index].id
    route_table_id = element(aws_route_table.private[*].id, count.index)
  }

  # Data -> Data RT
  resource "aws_route_table_association" "data" {
    count          = length(var.data_subnets)
    subnet_id      = aws_subnet.data[count.index].id
    route_table_id = aws_route_table.data.id
  }


# ==============================================================================
# 7. VPC Endpoint (S3 Gateway)
# ==============================================================================
  resource "aws_vpc_endpoint" "s3" {
    vpc_id       = aws_vpc.this.id
    service_name = "com.amazonaws.ap-northeast-2.s3"
    vpc_endpoint_type = "Gateway"

    tags = {
      Name = "courm-vpce-s3"
    }
  }
  # Private 서브넷용 S3 연결
resource "aws_vpc_endpoint_route_table_association" "private_s3" {
  count           = length(var.public_subnets) # Private RT 개수와 동일
  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}
  # Data 서브넷용 S3 연결
  resource "aws_vpc_endpoint_route_table_association" "data_s3" {
    route_table_id  = aws_route_table.data.id
    vpc_endpoint_id = aws_vpc_endpoint.s3.id
  }
