terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # Replace with your desired AWS region
}

# ------------------------------------------------------------------------------
# Networking Resources (VPC, Subnets, Internet Gateway, Route Table)
# Replace with your existing VPC and subnet IDs if applicable
# ------------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "blue-green-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Replace with your desired AZ
  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b" # Replace with your desired AZ
  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-routes"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name_prefix = "blue-green-instance-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80  # Allow HTTP for health checks (adjust as needed)
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blue-green-instance-sg"
  }
}

resource "aws_security_group" "alb" {
  name_prefix = "blue-green-alb-sg-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443 # Allow HTTPS traffic
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blue-green-alb-sg"
  }
}

# ------------------------------------------------------------------------------
# Launch Templates
# ------------------------------------------------------------------------------

resource "aws_launch_template" "blue" {
  name_prefix   = "blue-launch-template-"
  image_id      = "ami-xxxxxxxxxxxxxxxxx" # Replace with your desired Blue environment AMI
  instance_type = "t2.micro"              # Adjust instance type as needed
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(<<EOF
#!/bin/bash
echo "Hello from Blue Environment" > /var/www/html/index.html
yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2-mysql
systemctl start httpd
systemctl enable httpd
EOF
  )

  tags = {
    Environment = "Blue"
  }
}

resource "aws_launch_template" "green" {
  name_prefix   = "green-launch-template-"
  image_id      = "ami-yyyyyyyyyyyyyyyyy" # Replace with your desired Green environment AMI
  instance_type = "t2.micro"               # Adjust instance type as needed
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(<<EOF
#!/bin/bash
echo "Hello from Green Environment" > /var/www/html/index.html
yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2-mysql
systemctl start httpd
systemctl enable httpd
EOF
  )

  tags = {
    Environment = "Green"
  }
}

# ------------------------------------------------------------------------------
# Auto Scaling Groups
# ------------------------------------------------------------------------------

resource "aws_autoscaling_group" "blue" {
  name_prefix        = "blue-asg-"
  launch_template {
    id      = aws_launch_template.blue.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns   = [aws_lb_target_group.blue.arn]
  health_check_type   = "ELB"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 2

  tags = [
    {
      key                 = "Environment"
      value               = "Blue"
      propagate_at_launch = true
    },
  ]
}

resource "aws_autoscaling_group" "green" {
  name_prefix        = "green-asg-"
  launch_template {
    id      = aws_launch_template.green.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns   = [aws_lb_target_group.green.arn]
  health_check_type   = "ELB"
  desired_capacity    = 0 # Start with 0 instances for the green environment
  min_size            = 0
  max_size            = 2

  tags = [
    {
      key                 = "Environment"
      value               = "Green"
      propagate_at_launch = true
    },
  ]
}

# ------------------------------------------------------------------------------
# Application Load Balancers
# ------------------------------------------------------------------------------

resource "aws_lb" "blue" {
  name_prefix    = "blue-alb-"
  internal       = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false # Adjust as needed

  tags = {
    Environment = "Blue"
  }
}

resource "aws_lb_listener" "blue_https" {
  load_balancer_arn = aws_lb.blue.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Choose an appropriate SSL policy
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # Replace with your ACM certificate ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

resource "aws_lb" "green" {
  name_prefix    = "green-alb-"
  internal       = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false # Adjust as needed

  tags = {
    Environment = "Green"
  }
}

resource "aws_lb_listener" "green_https" {
  load_balancer_arn = aws_lb.green.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Choose an appropriate SSL policy
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy" # Replace with your ACM certificate ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }
}

# ------------------------------------------------------------------------------
# Target Groups
# ------------------------------------------------------------------------------

resource "aws_lb_target_group" "blue" {
  name_prefix = "blue-tg-"
  port        = 80 # Application port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  health_check {
    path     = "/" # Basic health check
    protocol = "HTTP"
    matcher  = "200"
    interval = 30
    timeout  = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Environment = "Blue"
  }
}

resource "aws_lb_target_group" "green" {
  name_prefix = "green-tg-"
  port        = 80 # Application port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  health_check {
    path     = "/" # Basic health check
    protocol = "HTTP"
    matcher  = "200"
    interval = 30
    timeout  = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Environment = "Green"
  }
}

# ------------------------------------------------------------------------------
# Route 53 Alias Records
# Replace with your Route 53 Hosted Zone ID and desired domain names
# ------------------------------------------------------------------------------

resource "aws_route53_record" "blue_alias" {
  zone_id = "YOUR_HOSTED_ZONE_ID" # Replace with your Route 53 Hosted Zone ID
  name    = "blue.example.com"    # Replace with your desired Blue environment subdomain
  type    = "A"

  alias {
    name                   = aws_lb.blue.dns_name
    zone_id                = aws_lb.blue.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green_alias" {
  zone_id = "YOUR_HOSTED_ZONE_ID" # Replace with your Route 53 Hosted Zone ID
  name    = "green.example.com"   # Replace with your desired Green environment subdomain
  type    = "A"

  alias {
    name                   = aws_lb.green.dns_name
    zone_id                = aws_lb.green.zone_id
    evaluate_target_health = true
  }
}

# ------------------------------------------------------------------------------
# Primary Route 53 Record for Traffic Switching
# ------------------------------------------------------------------------------

resource "aws_route53_record" "primary" {
  zone_id = "YOUR_HOSTED_ZONE_ID" # Replace with your Route 53 Hosted Zone ID
  name    = "app.example.com"     # Replace with your main application domain name
  type    = "A"

  # Initially point to the Blue environment
  alias {
    name                   = aws_lb.blue.dns_name
    zone_id                = aws_lb.blue.zone_id
    evaluate_target_health = true
  }

  # To switch traffic to the Green environment, you would update this resource
  # to point to the Green ALB:
  # alias {
  #   name                   = aws_lb.green.dns_name
  #   zone_id                = aws_lb.green.zone_id
  #   evaluate_target_health = true
  # }
}
