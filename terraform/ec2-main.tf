# Set up Terraform Cloud integration
terraform {
  cloud {
    organization = "TeraSky"

    workspaces {
      name = "demo-llm-tf-plan"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Define the AWS provider
provider "aws" {
  region = "us-east-1"
}

# Data source to fetch an existing default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to fetch subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a security group that allows all inbound traffic from 0.0.0.0/0 (open to the world)
resource "aws_security_group" "llm_demo_sg" {
  name        = "llm-demo-security-group"
  description = "Security group for LLM Demo allowing all inbound traffic"

  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # "-1" means all protocols
    cidr_blocks = ["0.0.0.0/0"]  # Open to the world
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "llm-demo-sg"
  }
}

# Create a t2.small EC2 instance within the default VPC and its subnets, using gp2 EBS volume
resource "aws_instance" "llm_demo_instance" {
  ami           = "ami-0fff1b9a61dec8a5f" # Example AMI, replace with your preferred AMI
  instance_type = "t2.small"
  subnet_id     = tolist(data.aws_subnets.default.ids)[0] # Use the first subnet from the list

  # Attach security group
  vpc_security_group_ids = [aws_security_group.llm_demo_sg.id]

  # Define root block device with gp2 volume type
  root_block_device {
    volume_type = "gp2"
    volume_size = 20 # Adjust the size as needed
  }

  tags = {
    Name = "llm-demo-instance"
  }
}
