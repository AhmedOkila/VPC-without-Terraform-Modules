#! Creating the VPC with its subnets
resource "aws_vpc" "myvpc" {
  cidr_block = var.myvpc_cidr
}
resource "aws_subnet" "myvpc_public_subnet_1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.myvpc_public_subnet_1
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # To indicate that it will be a public subnet
  tags = {
    "Name" = "public_subnet_1"
  }
}
resource "aws_subnet" "myvpc_public_subnet_2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.myvpc_public_subnet_2
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true # To indicate that it will be a public subnet
  tags = {
    "Name" = "public_subnet_2"
  }
}
#! Creating Internet Gateway and associate it to the VPC
resource "aws_internet_gateway" "gw" {}
resource "aws_internet_gateway_attachment" "attach_gw_to_myvpc" {
  internet_gateway_id = aws_internet_gateway.gw.id
  vpc_id              = aws_vpc.myvpc.id
}
#! Creating Routing Table and associate them to subnets
resource "aws_route_table" "myvpc_rt" {
  vpc_id = aws_vpc.myvpc.id

  # No Need to add this route as it will be created for us
  route {
    cidr_block = var.myvpc_cidr
    gateway_id = "local"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}
resource "aws_route_table_association" "public_subnet_1_a" {
  subnet_id      = aws_subnet.myvpc_public_subnet_1.id
  route_table_id = aws_route_table.myvpc_rt.id
}
resource "aws_route_table_association" "public_subnet_1_b" {
  subnet_id      = aws_subnet.myvpc_public_subnet_2.id
  route_table_id = aws_route_table.myvpc_rt.id
}

#! Creating the EC2 Instances and Security Groups
resource "aws_security_group" "sg" {
  name        = "myvpc_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "myvpc_sg"
  }
  egress {
    from_port   = 0    # To Indicate any port
    to_port     = 0    # To Indicate any port
    protocol    = "-1" #TCP
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "instance_1" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.myvpc_public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data              = base64encode(file("userdata.sh"))
  key_name               = var.key_name
  tags = {
    Name = "instance_1"
  }
}
resource "aws_instance" "instance_2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.myvpc_public_subnet_2.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data              = base64encode(file("userdata.sh"))
  #   user_data = base64encode(file("${path.module}/userdata.sh"))
  key_name = var.key_name
  tags = {
    Name = "instance_2"
  }
}
#! Creating S3 Bucket
# resource "aws_s3_bucket" "mys3" {
#   bucket = "my-s3_bucket_erfs456"
#   tags = {
#     Name = "My S3 Bucket"
#   }
# }
# resource "aws_s3_bucket_public_access_block" "block_public_access" {
#   bucket                  = aws_s3_bucket.mys3.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

#! Creating the ALB and Target Group
resource "aws_lb" "myalb" {
  name                       = "myalb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.sg.id]
  subnets                    = [aws_subnet.myvpc_public_subnet_1.id, aws_subnet.myvpc_public_subnet_2.id]
  enable_deletion_protection = false
}
resource "aws_lb_target_group" "tg" {
  name     = "alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id
}
resource "aws_lb_target_group_attachment" "instance_1_attachment_to_tg" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.instance_1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "instance_2_attachment_to_tg" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.instance_2.id
  port             = 80
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
# #? Creating the Outputs
output "load_balancer_dns" {
  value = aws_lb.myalb.dns_name
}
