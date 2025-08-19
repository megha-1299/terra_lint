terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = "ap-south-1" # apne region ka naam daalna
}

# ===================== VPC =====================
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"]
  }
}

# ===================== Subnets =====================
data "aws_subnet" "subnet_1" {
  filter {
    name   = "tag:Name"
    values = ["subnet_1"]
  }
}

data "aws_subnet" "subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["subnet_2"]
  }
}

# ===================== Security Group =====================
data "aws_security_group" "sg" {
  filter {
    name   = "tag:Name"
    values = ["sg"]
  }
}

# ===================== EKS Cluster =====================
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = data.aws_iam_role.worker_role.arn

  vpc_config {
    subnet_ids         = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]
    security_group_ids = [data.aws_security_group.sg.id]
  }

  depends_on = [data.aws_iam_role.worker_role]
}

# ===================== Node Group =====================
resource "aws_eks_node_group" "node_grp" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-node-group"
  node_role_arn   = data.aws_iam_role.worker_role.arn
  subnet_ids      = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

output "vpc_id" {
  value = data.aws_vpc.selected.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "node_group_name" {
  value = aws_eks_node_group.node_grp.node_group_name
}

