resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}
resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}
resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private-subnet"
  }
}
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "igw-01"
  }
}
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }
}
resource "aws_route_table_association" "public_rt_associate" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_network_acl" "pub-nacl" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "public-nacl"
  }
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
}
resource "aws_network_acl_association" "pub-nacl-assoc" {
  subnet_id      = aws_subnet.public-subnet.id
  network_acl_id = aws_network_acl.pub-nacl.id
}

resource "aws_eip" "my-eip" {
  domain = "vpc"
}
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.my-eip.id
  subnet_id     = aws_subnet.public-subnet.id
  tags = {
    Name = "my-nat-gw"
  }
  depends_on = [aws_internet_gateway.my-igw]
}
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
}
resource "aws_route_table_association" "private_rt_associate" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-rt.id
}
resource "aws_network_acl" "pri-nacl" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "private-nacl"
  }
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }
}
resource "aws_network_acl_association" "pri-nacl-assoc" {
  subnet_id      = aws_subnet.private-subnet.id
  network_acl_id = aws_network_acl.pri-nacl.id
}
resource "aws_security_group" "my-sg" {
  name   = "my-security-group"
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_key_pair" "mykey" {
  key_name   = "aws-key"
  public_key = tls_private_key.mykey.public_key_openssh
}
resource "tls_private_key" "mykey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "private_key" {
  content  = tls_private_key.mykey.private_key_pem
  filename = "aws-key.pem"
}
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy" "jenkins_policy" {
  name = "jenkins-policy"
  role = aws_iam_role.jenkins_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "ec2:DescribeInstances"
      ]

      Resource = "*"
    }]
  })
}
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

resource "aws_instance" "jenkins" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  user_data                   = file("ansible.sh")
  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "jenkins-server"
    Role = "jenkins"
  }
}
resource "aws_instance" "kube-main" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "kube-master"
    Role = "kubernetes"
  }
}
resource "aws_instance" "kube-worker_1" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "kube-worker-1"
    Role = "kubernetes"
  }
}
resource "aws_instance" "kube-worker_2" {
  ami                         = var.ami
  instance_type               = var.type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "kube-worker-2"
    Role = "kubernetes"
  }
}
resource "aws_instance" "docker" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "docker_main"
    Role = "docker"
  }
}
resource "aws_instance" "grafana" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "grafana01"
    Role = "grafana"
  }
}
resource "aws_instance" "prometheus" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.mykey.key_name
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = {
    Name = "prometheus01"
    Role = "prometheus"
  }
}
