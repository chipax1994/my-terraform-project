# aws_eip.one [elastic ip]
# aws_instance.web-server-instance
# aws_internet_gateway.gw
# aws_network_interface.web-server-nic
# aws_route_table.prod-route-table
# aws_route_table_association.a
# aws_security_group.allow_web
# aws_subnet.subnet-1
# aws_vpc.prod-vpc






provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

#create a vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "production"
  }
}


#create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}


#create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    "Name" = "prod"
  }
}


#create a subnet
resource "aws_subnet" "subnet-1" {
vpc_id = aws_vpc.prod-vpc.id
cidr_block = "10.0.1.0/24"
availability_zone = "us-east-1a"

tags = {
  "Name" = "prod-subnet"
}
}


#Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}


#create security group to allow port 22, 80, 443

resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port = 2
    to_port = 2
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "allow_web"
  }
}



#create a network interphase with an ip in the subnet
resource "aws_network_interface" "web-server-nic" {
  subnet_id = aws_subnet.subnet-1.id
  security_groups = [aws_security_group.allow_web.id]
  description = "network interface"
  private_ips = [ "10.0.1.50" ]
}


#Assign an elastic ip to the network interface created
resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

                                                                                                                                                                 

#create ubuntu server and install/enable apache2
 resource "aws_instance" "web-server-instance" {
  ami = "ami-0263e4deb427da90e"  
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id

  }


  user_data = <<-EOF
              #1/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c "echo your first web server >  /var/www/html/index.html"
              EOF

  tags = {
    "Name" = "web-server"
  }
}
