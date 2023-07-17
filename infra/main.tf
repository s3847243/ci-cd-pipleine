terraform {
  required_providers {
    aws = {
    source = "hashicorp/aws"
    version = "~> 4.0"
    }
  }
  # Using S3 bucket remote backend for state
  backend "s3" {
    bucket         = "s3-state-bucket-s3847243"     #S3 bucket name
    key            = "terraform.tfstate"     
    region         = "us-east-1"             
    encrypt        = true          # Enable server-side encryption
    dynamodb_table = "state-lock"  # Use DynamoDB for state locking
  }
}

# Region
provider "aws" {
  region = "us-east-1"
}

# Create an ubuntu-22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Key Pair
resource "aws_key_pair" "admin" {
  key_name   = "admin-key"
  public_key = file(var.public_key_file) #public_key_files is a variable - refer to vars.tf
}
########################VPC and Subnets#######################

# default vpc
data "aws_vpc" "default" {
  default = true
}
#default subnets
data "aws_subnets" "example" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

#####################EC2 instances############################

#EC2 Instance - 1 to deploy app container
resource "aws_instance" "app_server_1" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.admin.key_name
  security_groups = [aws_security_group.vm_app.name]

  tags = {
    Name = "App Server-1"
  }
}

#EC2 Instance - 2 to deploy app container
resource "aws_instance" "app_server_2" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.admin.key_name
  security_groups = [aws_security_group.vm_app.name]

  tags = {
    Name = "App Server-2"
  }
}

#EC2 Instance - 1 to deploy db container
resource "aws_instance" "db_server" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.admin.key_name
  security_groups = [aws_security_group.vm_db.name]

  tags = {
    Name = "DB server"
  }
}

##################Security Groups#####################

#security group for app ec2 instances
resource "aws_security_group" "vm_app" {
    name = "vm_app"
    #vpc_id = aws_vpc.main.id
    # SSH
    ingress {
      from_port = 0
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # HTTP in
    ingress {
      from_port = 0
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    # PostgreSQL out
    egress {
      from_port   = 0
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # HTTPS out
    egress {
        from_port = 0
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

#security group for db ec2 instances
resource "aws_security_group" "vm_db" {
    name = "vm_db"
    # PostgreSQL in
    ingress {
      from_port   = 0
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
     # PostgreSQL out
    egress {
      from_port   = 0
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

#security group for elb 
resource "aws_security_group" "lb" {
    name = "lb"
    ingress {
      from_port = 0
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
      from_port   = 0
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    # HTTP in
    ingress {
      from_port = 0
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  
  }
}

#################Load Balancer################
# creating a load balancer
resource "aws_lb" "app_lb" {
  name               = "my-app-lb"
  internal           = false
  load_balancer_type = "application"

  subnets            = data.aws_subnets.example.ids
  security_groups    = [aws_security_group.lb.id]
}
# setting up load balancer listener which sets the target group
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
#load balancer target group 
resource "aws_lb_target_group" "app_tg" {
  name     = "my-app-tg"
  port     = 80
  protocol = "HTTP"

  target_type = "instance"

  vpc_id = data.aws_vpc.default.id
}

# attaching target group to ec2 instances deploying app server 
resource "aws_lb_target_group_attachment" "app1_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server_1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "app2_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server_2.id
  port             = 80
}

#####################################
# Output the required public/private IP addresses:
# These IP addresses are used in ansible playbook/inventory files
output "app_instance1_public_ip" {
  value = aws_instance.app_server_1.public_ip
}

output "app_instance2_public_ip" {
  value = aws_instance.app_server_2.public_ip
}

output "db_instance_public_ip" {
  value = aws_instance.db_server.public_ip
}

output "db_instance_private_ip" {
  value = aws_instance.db_server.private_ip
}
#####################################