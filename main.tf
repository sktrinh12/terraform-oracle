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
    Application = "Oracle"
    Created     = "TF"
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
        "s3:Get*",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::fount-data",
        "arn:aws:s3:::fount-data/*"
      ]
  },
  {
      "Action": [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:PutObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::fount-data/DevOps",
        "arn:aws:s3:::fount-data/DevOps/*"
       ]
  }
  ]
}
EOF
}

# resource "aws_volume_attachment" "or_ebs_att" {
#    count         = length(var.disk_names)
#    device_name = "${var.disk_names[count.index]}"
#    volume_id   = "${element(aws_ebs_volume.orebs.*.id, count.index)}"
#    instance_id = "${element(aws_instance.ortest.*.id, count.index)}"
# }
#
#resource "aws_ebs_volume" "orebs" {
  # count             = length(var.disk_names)
  # availability_zone = "us-west-2"
  # size              = var.disk_size[count.index]
  # type              = "gp3"
  # iops              = var.disk_iops[count.index]
  #
  # tags = {
  # Name = "or_ebs_${count.index}"
  # EC2_Instance = "oracle_ec2_${count.index +1}"
  # }
# }

# EC2 resource
resource "aws_instance" "ortest" {
  count         = var.awsprops.count
  ami           = var.awsprops.ami
  instance_type = var.awsprops.itype
  subnet_id     = var.awsprops.subnet 
  key_name      = var.awsprops.keyname

  root_block_device {
    volume_size = var.awsprops.volume_size
    volume_type = var.awsprops.volume_type
    delete_on_termination = true
    iops = 150
  }

  # Copy in the bash script we want to execute.
  # The source is the location of the bash script
  # on the local system you are executing terraform
  # from.  The destination is on the new AWS instance.
  provisioner "file" {
    source      = "./config-files/${var.shfile}"
    destination = "/home/ec2-user/${var.shfile}"
  }

  provisioner "file" {
    source      = "./config-files/${var.bkpfile}"
    destination = "/home/ec2-user/${var.bkpfile}"
  }

  # Change permissions on bash script and execute
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/${var.shfile}",
      "sudo /home/ec2-user/${var.shfile} ${var.license} ${var.recovery_date}",
    ]
  }

  # Establishes connection to be used by all
  # generic remote provisioners (i.e. file/remote-exec)
  connection {
    host  = self.private_ip
    agent = true
    type  = "ssh"
    user  = "ec2-user"
    private_key = file(pathexpand("~/.ssh/eks-apps.pem"))
  }
  
  vpc_security_group_ids = [
    module.security_group.ec2_sg_private
  ]
     
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_ortest.name

  tags = {
    Application = "Oracle"
    Name        = "oracle_ec2_${count.index +1}"
    Created     = "TF"
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

