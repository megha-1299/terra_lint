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
  region = "ap-south-1"
}

# ==========================
# Use existing IAM Roles & Policy as Data Sources
# ==========================

# Fetch existing Master Role
data "aws_iam_role" "master" {
  name = "veera-eks-master1"
}

# Fetch existing Worker Role
data "aws_iam_role" "worker" {
  name = "veera-eks-worker1"
}

# Fetch existing Autoscaler Policy
data "aws_iam_policy" "autoscaler" {
  name = "veera-eks-autoscaler-policy1"
}

# ==========================
# Attach IAM Policies to Roles
# ==========================
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = data.aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = data.aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = data.aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = data.aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = data.aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = data.aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = data.aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = data.aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "autoscaler" {
  policy_arn = data.aws_iam_policy.autoscaler.arn
  role       = data.aws_iam_role.worker.name
}

# ==========================
# Use existing Instance Profile (Datasource instead of Resource)
# ==========================
data "aws_iam_instance_profile" "worker" {
  name = "veera-eks-worker-new-profile3"
}

# ==========================
# Fetch existing VPC, Subnets, SG
# ==========================
data "aws_vpc" "main" {
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
  vpc_id = data.aws_vpc.main.id
}

data "aws_subnet" "subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["subnet_2"]
  }
  vpc_id = data.aws_vpc.main.id
}

data "aws_security_group" "selected" {
  filter {
    name   = "tag:Name"
    values = ["sg"] # Replace with your SG tag value
  }
  vpc_id = data.aws_vpc.main.id
}

# ==========================
# EKS Cluster
# ==========================
resource "aws_eks_cluster" "eks" {
  name     = "project-eks"
  role_arn = data.aws_iam_role.master.arn

  vpc_config {
    subnet_ids = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]
  }

  tags = {
    "Name" = "MyEKS"
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}

# ==========================
# Node Group
# ==========================
resource "aws_eks_node_group" "node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "project-node-group"
  node_role_arn   = data.aws_iam_role.worker.arn
  subnet_ids      = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]

  capacity_type   = "ON_DEMAND"
  disk_size       = 20
  instance_types  = ["t2.small"]

  remote_access {
    ec2_ssh_key               = "lint"
    source_security_group_ids = [data.aws_security_group.selected.id]
  }

  labels = {
    env = "dev"
  }

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
