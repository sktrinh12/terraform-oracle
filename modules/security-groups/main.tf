resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Security group for ec2_sg - enable specified ports"
  vpc_id      = var.vpc_id

  ingress { 
    description = "http access"
    from_port = 1521
    to_port = 1521
    protocol = "tcp" 
    cidr_blocks = ["10.75.0.0/16", "10.0.0.0/16"]
  }

  ingress {
    description = "http access"
    from_port = 80 
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["10.75.0.0/16", "10.0.0.0/16"]
    }

  ingress {
    description = "ssh access"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["10.75.0.0/16", "10.0.0.0/16"]
    }

  ingress {
    description = "https access"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  egress {
    description = "open to all out-going"
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
}
  tags = {
    Name = "ec2 sg"
  }
}
