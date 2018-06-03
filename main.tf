
##########################Providers

provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc-cidr}"
  enable_dns_hostnames = true
}


# Public Subnets
resource "aws_subnet" "subnet-a" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-a}"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "subnet-b" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-b}"
  availability_zone = "${var.region}b"
}

resource "aws_subnet" "subnet-c" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet-cidr-c}"
  availability_zone = "${var.region}c"
}

resource "aws_route_table" "subnet-route-table" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route" "subnet-route" {
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = "${aws_internet_gateway.igw.id}"
  route_table_id          = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-a-route-table-association" {
  subnet_id      = "${aws_subnet.subnet-a.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-b-route-table-association" {
  subnet_id      = "${aws_subnet.subnet-b.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}

resource "aws_route_table_association" "subnet-c-route-table-association" {
  subnet_id      = "${aws_subnet.subnet-c.id}"
  route_table_id = "${aws_route_table.subnet-route-table.id}"
}


# Nginx machine 1 #####################################

resource "aws_instance" "instance1" {
  ami           = "ami-cdbfa4ab"
  instance_type = "t2.small"
  vpc_security_group_ids      = [ "${aws_security_group.security-group.id}" ]
  subnet_id                   = "${aws_subnet.subnet-a.id}"
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}

# Nginx machine 2 #####################################

resource "aws_instance" "instance2" {
  ami           = "ami-cdbfa4ab"
  instance_type = "t2.small"
  vpc_security_group_ids      = [ "${aws_security_group.security-group.id}" ]
  subnet_id                   = "${aws_subnet.subnet-a.id}"
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/sh
yum install -y nginx
service nginx start
EOF
}

# Bastion server #######################################

resource "aws_instance" "instance3" {
  ami           = "ami-cdbfa4ab"
  instance_type = "t2.small"
  vpc_security_group_ids      = [ "${aws_security_group.bation.id}" ]
  subnet_id                   = "${aws_subnet.subnet-a.id}"
  associate_public_ip_address = true
}


###############################Security group of web machines#################################################################


resource "aws_security_group" "security-group" {
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress = [
    {
      from_port = "80"
      to_port   = "80"
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port = "443"
      to_port   = "443"
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###########################Security group of bation machine ###############################################

resource "aws_security_group" "bation" {
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress = [
    {
      from_port = "22"
      to_port   = "22"
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "22"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


##################################################ELB ##########################################


resource "aws_elb" "bar" {
  name               = "foobar-terraform-elb"
  availability_zones = ["${var.region}a", "${var.region}b", "${var.region}c"]


  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }

  instances                   = ["${aws_instance.instance1.id}","${aws_instance.instance2.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "foobar-terraform-elb"
  }
}

###############################################################################################


output "nginx_domain" {
  value = "${aws_instance.instance.public_dns}"
}
