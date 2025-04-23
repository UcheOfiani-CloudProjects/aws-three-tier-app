provider "aws" {
  region = "us-east-1"  # Specify your preferred AWS region
}

 #Get available availability zones dynamically
data "aws_availability_zones" "available" {}

# Reference the VPC module (located inside the 'modules' folder)
module "vpc" {
  source      = "./modules/vpc"  # Path to the VPC module
  project     = "aws-three-tier-app"  # Optional, can be a name or identifier for your project
  vpc_cidr    = "10.0.0.0/16"    # Define your CIDR block for the VPC

  azs         = data.aws_availability_zones.available.names  # Pass the available AZs to the VPC module

  # Define the CIDR blocks for public and private subnets
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]  # Example public subnets across 2 AZs
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]  # Example private subnets across 2 AZs
}

# Create an EC2 instance in the Public Subnet (Web Server)
resource "aws_instance" "web_server" {
  ami           = "ami-0c101f26f147fa7fd"
 # Replace with the desired AMI ID
  instance_type = "t2.micro"               # Define the EC2 instance type
  subnet_id     = module.vpc.public_subnet_ids[0]  # Use the first public subnet
  tags = {
    Name = "WebServer"
  }
}

# Create an EC2 instance in the Private Subnet (App Server)
resource "aws_instance" "app_server" {
  ami           = "ami-0c101f26f147fa7fd" # Replace with the desired AMI ID
  instance_type = "t2.micro"               # Define the EC2 instance type
  subnet_id     = module.vpc.private_subnet_ids[0]  # Use the first private subnet

  tags = {
    Name = "AppServer"
  }
}

# Create an Application Load Balancer (ALB) for Web Servers
resource "aws_lb" "web_lb" {
  name               = "web-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]  # Use the security group for the LB
  subnets            = module.vpc.public_subnet_ids # Use the public subnet for the ALB
  enable_deletion_protection = false

  enable_cross_zone_load_balancing = true
  enable_http2                     = true

  tags = {
    Name = "WebAppLB"
  }
}

# Create a Security Group for Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "web_lb_sg"
  description = "Allow inbound HTTP and HTTPS traffic for the load balancer"
  vpc_id      = module.vpc.vpc_id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output values for the deployed resources
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
}

output "app_server_private_ip" {
  value = aws_instance.app_server.private_ip
}
