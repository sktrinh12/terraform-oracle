# EC2 IAM ROLE
resource "aws_iam_role" "ec2_role_ortest" {
  name = "ec2_role_ortest"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Application = "ortest"
    Created ="TF"
    Environment = "Development"
  }
}

# EC2 IAM PROFILE
resource "aws_iam_instance_profile" "ec2_profile_ortest" {
  name = "ec2_profile_ortest"
  role = aws_iam_role.ec2_role_ortest.name
}

# EC2 IAM POLICY
resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role_ortest.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
  "Resource": [
      "arn:aws:s3:::*/*",
      "arn:aws:s3:::fount-data/DevOps"
   ]
    }
  ]
}
EOF
}

# EC2 resource
resource "aws_instance" "ortest" {
  ami           = var.awsprops.ami
  instance_type = var.awsprops.itype
  subnet_id = var.awsprops.subnet 
  key_name = var.awsprops.keyname

  root_block_device {
    volume_size = var.awsprops.volume_size
    volume_type = var.awsprops.volume_type
    delete_on_termination = true
    iops = 150
  }

  # Copy in the bash script we want to execute.
  # The source is the location of the bash script
  # on the local linux box you are executing terraform
  # from.  The destination is on the new AWS instance.
  # provisioner "file" {
  #   source      = "oracle_install.sh"
  #   destination = "/tmp/oracle_install.sh"
  # }

  # # Change permissions on bash script and execute from ec2-user.
  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /tmp/oracle_install.sh",
  #     "sudo /tmp/oracle_install.sh",
  #   ]
  # }

  # # Establishes connection to be used by all
  # # generic remote provisioners (i.e. file/remote-exec)
  # connection {
  #   host = self.private_ip
  #   agent = true
  #   type = "ssh"
  #   user = "ec2-user"
  #   private_key = file(pathexpand("~/.ssh/eks-apps.pem"))
  # }
  
  vpc_security_group_ids = [
    module.security_group.ec2_sg_private
  ]
     
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_ortest.name

  tags = {
    Application = "ortest"
    Name = "ortest"
    Created ="TF"
    Environment = "Development"
  }

  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

module "security_group" {
    source = "./modules/security-groups"
    vpc_id = var.awsprops.vpc
}

output "ec2instance" {
  value = aws_instance.ortest.private_ip
}
