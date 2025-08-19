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

# -------------------------
# DATA SOURCES
# -------------------------
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"]
  }
}

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

data "aws_security_group" "sg" {
  filter {
    name   = "tag:Name"
    values = ["sg"]
  }
}

data "aws_iam_role" "worker_role" {
  name = "veera-eks-worker-new-role"
}

# -------------------------
# EKS CLUSTER
# -------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = data.aws_iam_role.worker_role.arn

  vpc_config {
    subnet_ids         = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]
    security_group_ids = [data.aws_security_group.sg.id]
  }

  depends_on = [data.aws_iam_role.worker_role]
}

# -------------------------
# EKS NODE GROUP
# -------------------------
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

  depends_on = [aws_eks_cluster.eks_cluster]
}
output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_security_group_id" {
  value = data.aws_security_group.sg.id
}

output "subnet_ids" {
  value = [
    data.aws_subnet.subnet_1.id,
    data.aws_subnet.subnet_2.id
  ]
}
