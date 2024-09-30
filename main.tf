provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "skdemo_vpc" {
  cidr_block = "10.0.0.0/16" ## its Private network with 16 subnet (16 for network and 16 for host address, total 65.536 IP )

  tags = {
    Name = "skdemo-vpc"
  }
}
resource "aws_subnet" "skdemo_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.skdemo_vpc
  cidr_block              = cidrsubnet(aws_vpc.skdemo_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1", "us-east-2"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "skdemo-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "skdemo_igw" {
  vpc_id = aws_vpc.skdemo_vpc.id

  tags = {
    Name = "skdemo-igw"
  }
}
resource "aws_route_table" "skdemo_route_table" {
  vpc_id = aws_vpc.skdemo_vpc.id

  route = {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.skdemo_igw.id
  }
  tags = {
    Name = "skdemo-route-table"
  }
}
resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.skdemo_subnet[count.index].id
  route_table_id = aws_route_table.skdemo_route_table.id
}

resource "aws_security_group" "skdemo_cluster_sg" {
  vpc_id = aws_vpc.skdemo_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skdemo-cluster-sg"
  }
}
resource "aws_security_group" "skdemo_node_sg" {
    vpc_id = aws_subnet.skdemo_subnet.id

    ingress {
        from_port = 0
        to_port = 0
        protocol   = "-1"
        cidr_block = ["0.0.0.0/0"]
  }
    egress {
        from_port  = 0
        to_port    = 0
        protocol   = "-1"
        cidr_block = ["0.0.0.0/0"]
  }
    tags = {
    Name = "skdemo-node-sg"
  }
}

resource "aws_eks_cluster" "skdemo_cluster" {
    name = "skdemo-cluster"
    role_arn = aws_iam_role.skdemo_cluster.role_arn

    vpc_config {
      subnet_ids = aws_subnet.skdemo_subnet[*].id
      security_group_ids = [aws_security_group.skdemo_cluster_sg.id]
    }
}

resource "aws_eks_node_group" "skdemo_cluster" {
    cluster_name    = aws_eks_cluster.skdemo_cluster.name
    node_group_name = "skdemo-node-group"
    node_role_arn   = aws_iam_role.skdemo_node_group_role.role_arn
    subnet_ids = aws_subnet.skdemo_subnet[*].id

    scaling_config {
      desired_size = 3
      max_size = 3
      min_size = 3
    }

instance_types = ["t2.large"]

remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.skdemo_node_sg.id]
    }
}

resource "aws_iam_role" "skdemo_cluster_role" {
    name = "skdemo-cluster-role"

    assume_role_policy = << EOF
{
        "Version": "2012-10-17",
        "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
        "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "skdemo_cluster_role_policy" {
  role       = aws_iam_role.skdemo_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "skdemo_node_group_role" {
  name = "skdemo-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "skdemo_node_group_role_policy" {
  role       = aws_iam_role.skdemo_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "skdemo_node_group_cni_policy" {
  role       = aws_iam_role.skdemo_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "skdemo_node_group_registry_policy" {
  role       = aws_iam_role.skdemo_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}