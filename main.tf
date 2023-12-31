terraform {
    //download the required providers
    required_providers{
        aws={
            source = "hashicorp/aws"
            version = "~> 3.5.0"
        }
    }
}

//setup provider region
provider "aws" {
    region = "eu-central-1"
}


//vpc
resource "aws_vpc" "custom_vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "TVACustomVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "TVAPublicSubnet"
  }
}
resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "192.168.3.0/24"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "TVAPublicSubnet2"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.custom_vpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "TVAPrivateSubnet"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.custom_vpc.id  
}

resource "aws_route" "internet_gateway" {
  route_table_id         = aws_vpc.custom_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}



resource "aws_security_group" "allow_http" {
  name_prefix = "allow-http"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow-ssh"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



//load balancer
resource "aws_lb" "lb" {
  name               = "TVAlb"
  internal           = false
  load_balancer_type = "application"
  security_groups = [ aws_security_group.allow_ssh.id, aws_security_group.allow_http.id]
  subnets            = [aws_subnet.public_subnet.id,aws_subnet.public_subnet2.id] 
}

resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom_vpc.id 

  lifecycle {
    replace_triggered_by = [ aws_lb.lb.id ]
  }
}

//auto scaling and launch group
resource "aws_launch_configuration" "launch" {
  name_prefix   = "launch-cfg"
  image_id      = var.ami_id
  instance_type = var.instance_type

  security_groups = [ aws_security_group.allow_ssh.id, aws_security_group.allow_http.id]

  lifecycle {
    replace_triggered_by = [ aws_lb_target_group.example.id ]
  }
}

resource "aws_autoscaling_group" "ats" {
  name                 = "autoscalingV"
  launch_configuration = aws_launch_configuration.launch.name
  min_size             = var.min_size
  max_size             = var.max_size
  desired_capacity     = var.desired_capacity
  vpc_zone_identifier = [aws_subnet.public_subnet.id,aws_subnet.public_subnet2.id]
  
  target_group_arns = [aws_lb_target_group.example.id]

  lifecycle {
    replace_triggered_by = [ aws_launch_configuration.launch.id, aws_lb_target_group.example.id ]
  }
}

//loadbalancer listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type= "forward"
  }

  lifecycle {
    replace_triggered_by = [ aws_lb_target_group.example.id, aws_autoscaling_group.ats.id ]
  }
}



