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
#resource "aws_instance" "app_server" {
  #ami           = "ami-0c101f26f147fa7fd" # Replace with the desired AMI ID
  #instance_type = "t2.micro"               # Define the EC2 instance type
  #subnet_id     = module.vpc.private_subnet_ids[0]  # Use the first private subnet

  #tags = {
   # Name = "AppServer"
 # }
#}

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

# Create a security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow MySQL from app servers"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Ensure app_sg exists
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Allow traffic from app server to RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Or use app_server_sg if defined
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# Reference the existing VPC by its ID
data "aws_vpc" "main" {
  id = "vpc-0db764055ffd2f69a"
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = data.aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"  # Use an appropriate CIDR block for your public subnet
  availability_zone       = "us-east-1a"    # Choose the appropriate AZ for your region
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group for Bastion Host"
  vpc_id      = data.aws_vpc.main.id  # Ensure it's using the correct VPC (data block)

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access (you can restrict this to your IP)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

resource "aws_instance" "bastion1" {
  ami           = "ami-0c101f26f147fa7fd"  # Amazon Linux AMI (check your region)
  instance_type = "t2.micro"
  key_name      = "Main-key"  # Use your key pair here
  subnet_id     = aws_subnet.public_subnet.id  # Choose the public subnet
  security_groups = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "Bastion Host"
  }
}

# RDS Instance
resource "aws_db_instance" "app_db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "appdb"
  username             = var.db_username
  password             = var.db_password
  publicly_accessible  = false
  multi_az             = false
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  db_subnet_group_name = aws_db_subnet_group.default.name
  skip_final_snapshot  = true
}

# DB Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name = "My DB subnet group"
  }
}

# Create A Launch Template
resource "aws_launch_template" "app_template" {
  name_prefix   = "app-launch-template-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = "Main-key" 
  # Reference the user_data script
  user_data = base64encode(file("scripts/user_data.sh"))
  
  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.app_sg.id]
    subnet_id       = element(module.vpc.private_subnet_ids, 0) # any private subnet
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "AppServer"
    }
  }

}


resource "aws_lb_target_group" "web_tg" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "web-target-group"
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Create the Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name                      = "app-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 2
  vpc_zone_identifier       = module.vpc.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "AppServer"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
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

output "rds_endpoint" {
  value = aws_db_instance.app_db.endpoint
}
