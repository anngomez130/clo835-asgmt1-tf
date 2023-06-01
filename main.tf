provider "aws" {
  region = "us-east-1"
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create EC2 instance
resource "aws_instance" "this" {
  ami                  = data.aws_ami.latest_amazon_linux.id
  instance_type        = "t2.micro"
  iam_instance_profile = "LabInstanceProfile"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user

    cd /home/ec2-user

    # Export ECR variables
    echo "#!/bin/bash" >> exports.sh
    echo "export WEB_ECR="${aws_ecr_repository.web.repository_url}"" >> exports.sh
    echo "export SQL_ECR="${aws_ecr_repository.sql.repository_url}"" >> exports.sh

    # Export mysql variables
    echo "export DBHOST="mysql"" >> exports.sh
    echo "export DBPORT="3306"" >> exports.sh
    echo "export DBUSER="root"" >> exports.sh
    echo "export DATABASE="employees"" >> exports.sh
    echo "export DBPWD="pw"" >> exports.sh
    echo 'aws ecr get-login-password --region us-east-1 | docker login -u AWS $WEB_ECR --password-stdin' >> exports.sh
    
    chmod +x exports.sh
    
    source exports.sh
  EOF

  tags = {
    Name = "asgmt1-vm"
  }
}

# Create ECR Repository
resource "aws_ecr_repository" "web" {
  name = "webapp"
}

resource "aws_ecr_repository" "sql" {
  name = "mysql"
}

# Retrieve the default VPC
data "aws_vpc" "default" {
  default = true
}

# Retrieve the default subnets associated with the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create ALB
resource "aws_lb" "this" {
  name               = "asgmt1-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "asgmt1-alb"
  }
}

# Create ALB listeners
resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

# Create ALB listener rules to forward requests to target groups based on paths
resource "aws_lb_listener_rule" "blue" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
  condition {
    path_pattern {
      values = ["/blue"]
    }
  }
}

resource "aws_lb_listener_rule" "pink" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 200
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pink.arn
  }
  condition {
    path_pattern {
      values = ["/pink"]
    }
  }
}

resource "aws_lb_listener_rule" "lime" {
  listener_arn = aws_lb_listener.this.arn
  priority     = 300
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lime.arn
  }
  condition {
    path_pattern {
      values = ["/lime"]
    }
  }
}

# Create target groups
resource "aws_lb_target_group" "blue" {
  name     = "asgmt1-blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "pink" {
  name     = "asgmt1-pink-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "lime" {
  name     = "asgm1-lime-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create target group attachments
resource "aws_lb_target_group_attachment" "blue" {
  target_group_arn = aws_lb_target_group.blue.arn
  target_id        = aws_instance.this.id
  port             = 8081
}

resource "aws_lb_target_group_attachment" "pink" {
  target_group_arn = aws_lb_target_group.pink.arn
  target_id        = aws_instance.this.id
  port             = 8082
}

resource "aws_lb_target_group_attachment" "lime" {
  target_group_arn = aws_lb_target_group.lime.arn
  target_id        = aws_instance.this.id
  port             = 8083
}