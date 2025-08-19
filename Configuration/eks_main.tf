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
  region = "ap-south-1"  # Specify your desired region
}

 #Creating IAM role for EKS
  resource "aws_iam_role" "master" {
    name = "veera-eks-master1"

    assume_role_policy = jsonencode({
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
    })
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role" "worker" {
    name = "veera-eks-worker1"

    assume_role_policy = jsonencode({
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
    })
  }

  resource "aws_iam_policy" "autoscaler" {
    name = "veera-eks-autoscaler-policy1"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeTags",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "ec2:DescribeLaunchTemplateVersions"
          ],
          "Effect": "Allow",
          "Resource": "*"
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "s3" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "autoscaler" {
    policy_arn = aws_iam_policy.autoscaler.arn
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_instance_profile" "worker" {
    depends_on = [aws_iam_role.worker]
    name       = "veera-eks-worker-new-profile2"
    role       = aws_iam_role.worker.name
  }
 
 # data source 
# Fetch existing VPC by Name
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"]
  }
}

# Fetch existing Subnet 1 by Name
data "aws_subnet" "subnet_1" {
  filter {
    name   = "tag:Name"
    values = ["subnet_1"]
  }

  vpc_id = data.aws_vpc.main.id
}

# Fetch existing Subnet 2 by Name
data "aws_subnet" "subnet_2" {
  filter {
    name   = "tag:Name"
    values = ["subnet_2"]
  }

  vpc_id = data.aws_vpc.main.id
}

# Fetch existing Security Group by Name (if you want by Name instead of ID)
data "aws_security_group" "selected" {
  filter {
    name   = "tag:Name"
    values = ["my-sg"]   # <-- Replace with your SG name if available
  }

  vpc_id = data.aws_vpc.main.id
}

 #Creating EKS Cluster
  resource "aws_eks_cluster" "eks" {
    name     = "project-eks"
    role_arn = aws_iam_role.master.arn

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
 resource "aws_eks_node_group" "node-grp" {
    cluster_name    = aws_eks_cluster.eks.name
    node_group_name = "project-node-group"
    node_role_arn   = aws_iam_role.worker.arn
    subnet_ids = [data.aws_subnet.subnet_1.id, data.aws_subnet.subnet_2.id]

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


/*
provider "aws" { 
  region = "us-east-1"   # change this to your preferred region
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name-1234554546765464"

  acl = "private"

  tags = {
    Name        = "MyBucket"
    Environment = "Dev"
  }
}

*/
