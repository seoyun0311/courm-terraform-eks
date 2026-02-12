resource "aws_instance" "jenkins" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id     = var.subnet_id

  # SSH 접속용 키 페어
  key_name      = var.key_name
  private_ip  = "10.0.30.246"
  iam_instance_profile = aws_iam_instance_profile.jenkins_ssm_profile.name

  # 보안 그룹
  vpc_security_group_ids = var.security_group_ids

  tags = {
    Name = var.name
    Service = "jenkins"
  }
}

# 1. EC2가 사용할 IAM 역할 생성
resource "aws_iam_role" "jenkins_ssm_role" {
  name = "${var.name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. AWS 관리형 정책(AmazonSSMManagedInstanceCore) 연결
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.jenkins_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. 인스턴스에 부착하기 위한 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "jenkins_ssm_profile" {
  name = "${var.name}-ssm-profile"
  role = aws_iam_role.jenkins_ssm_role.name
}

# EKS 클러스터 조회 및 접근을 위한 정책 생성
resource "aws_iam_policy" "jenkins_eks_policy" {
  name        = "${var.name}-eks-policy"
  description = "Allow Jenkins to access EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# 위 정책을 젠킨스 역할에 연결
resource "aws_iam_role_policy_attachment" "jenkins_eks_attach" {
  role       = aws_iam_role.jenkins_ssm_role.name
  policy_arn = aws_iam_policy.jenkins_eks_policy.arn
}
