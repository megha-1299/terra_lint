terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# -------------------------
# Data Sources
# -------------------------

# VPC by Name
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"]
  }
}

# Subnets by Name
data "aws_subnet" "subnet1" {
  filter {
    name   = "tag:Name"
    values = ["subnet_1"]
  }
  vpc_id = data.aws_vpc.selected.id
}

data "aws_subnet" "subnet2" {
  filter {
    name   = "tag:Name"
    values = ["subnet_2"]
  }
  vpc_id = data.aws_vpc.selected.id
}

# Security Group by Name
data "aws_security_group" "eks_sg" {
  filter {
    name   = "group-name"
    values = ["sg"]
  }
  vpc_id = data.aws_vpc.selected.id
}

# IAM Role for Worker Nodes
data "aws_iam_role" "worker_role" {
  name = "veera-eks-worker-role"
}

# IAM Instance Profile for Worker Nodes
data "aws_iam_instance_profile" "worker_profile" {
  name = "veera-eks-worker-new-profile2"
}

# -------------------------
# EKS Cluster
# -------------------------

resource "aws_eks_cluster" "eks_cluster" {
  name     = "veera-eks"
  role_arn = data.aws_iam_role.worker_role.arn

  vpc_config {
    subnet_ids         = [data.aws_subnet.subnet1.id, data.aws_subnet.subnet2.id]
    security_group_ids = [data.aws_security_group.eks_sg.id]
  }

  depends_on = [
    data.aws_iam_role.worker_role
  ]
}

# -------------------------
# EKS Node Group
# -------------------------

resource "aws_eks_node_group" "node_grp" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "veera-eks-ng"
  node_role_arn   = data.aws_iam_role.worker_role.arn
  subnet_ids      = [data.aws_subnet.subnet1.id, data.aws_subnet.subnet2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}
