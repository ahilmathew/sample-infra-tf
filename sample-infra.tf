variable "aws_access_key" {
    type=string
}
variable "aws_secret_key" {
    type=string
}
variable "aws_region" {
    type=string
}
variable "key_name" {
    type=string
}
variable "key_path" {
    type=string
}
variable "availability_zone" {
  default = "us-west-2a"
}
variable "ingress_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
variable "instance_type" {
  type    = string
  default = "t2.micro"
}
# Set up the AWS provider.
provider "aws" {
    access_key  = var.aws_access_key
    secret_key  = var.aws_secret_key
    region      = var.aws_region
}
# Search the latest amazon linux 2 AMI.
data "aws_ami" "amazon-linux-2" {
    most_recent = true

    filter {
    name   = "owner-alias"
    values = ["amazon"]
    }

    filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
    }
    owners = ["amazon"]
}

# Create a new VPC using the 10.0.0.0/16 CIDR block
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main"
  }
}
# Create a new subnet for the created VPC
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = {
    Name = "main"
  }
}
# Create a new internet gateway for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main"
  }
}
# Add a route to access internet gateway
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = {
    "Name" = "main"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Create a new security group that allows inbound http requests
resource "aws_security_group" "nginx-server" {
    name        = "nginx-server"
    description = "Allow HTTP and SSH traffic"
    vpc_id      = aws_vpc.main.id

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr
    }
    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ingress_cidr
    }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# Create a new instance of the latest Amazon Linux 2 on an
# t2.micro(default) node with an AWS Tag naming it "nginx-server-01"
resource "aws_instance" "nginx_server_01" {
    ami               = data.aws_ami.amazon-linux-2.id
    instance_type     = var.instance_type
    subnet_id         = aws_subnet.main.id
    key_name          = var.key_name
    user_data         = file("scripts/install.sh")
    availability_zone = var.availability_zone
    tags = {
        Name = "nginx-server-01"
    }
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.key_path)
      host        = self.public_dns
    }
    provisioner "file" {
        source      = "config/nginx.conf"
        destination = "/tmp/nginx.conf"
    }
    provisioner "file" {
        source      = "scripts/health-stats.sh"
        destination = "/tmp/health-stats.sh"
    }
    provisioner "file" {
        source      = "nodeapp"
        destination = "/tmp"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/nginx/nodeapp",
            "sudo cp /tmp/nginx.conf /etc/nginx/",
        ]
    }
    # Wating for cloud init(user data) operations to complete
    provisioner "remote-exec" {
        inline = [
            "sudo cloud-init status --wait > /dev/null 2>&1"
        ]
    }
    # Perform all file operations, start health check script, start docker containers
    provisioner "remote-exec" {
        inline = [
            "sudo cp /tmp/health-stats.sh /etc/nginx/health-stats.sh",
            "sudo cp -r /tmp/nodeapp/* /etc/nginx/nodeapp/",
            "sudo chmod +x /etc/nginx/health-stats.sh",
            "sudo touch /etc/resource.log",
            "nohup sudo /bin/bash /etc/nginx/health-stats.sh &",
            "sleep 1",
            "cd /etc/nginx/nodeapp",
            "sudo docker build . -t nodeapp:latest",
            "sudo docker run --name nodeapp -v /etc/resource.log:/etc/resource.log -p 3000:3000 -d nodeapp --restart always",
            "sudo docker network create appnetwork --opt com.docker.network.bridge.name=br_app_access",
            "sudo docker network connect appnetwork nginx",
            "sudo docker network connect appnetwork nodeapp",
        ]
    }
    vpc_security_group_ids = [
        aws_security_group.nginx-server.id,
    ]
}
output "application_url" {
  value = "http://${aws_instance.nginx_server_01.public_dns}/logs"
}