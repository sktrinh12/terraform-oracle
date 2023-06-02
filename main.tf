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
    Application = "Oracle DB"
    Name        = "Dotmatics-DEV-ORA-DB"
    Created_by     = "TF"
    Environment = "dev"
    Function = "Discovery"
    OS	= "Oracle Linux" 
    Owner	= "Informatics"
    Application_version = "19c"
    Notes = "Development Dotmatics 2022.3 Oracle DB Server - 19c"
    Depends_on = "Dotmatics"
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
  },
  {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "*"
  }
  ]
}
EOF
}

resource "aws_volume_attachment" "or_ebs_att" {
    count = var.awsprops.count * length(var.disk_names)
    device_name = element(var.disk_names, count.index % length(var.disk_names))
    volume_id   = aws_ebs_volume.orebs.*.id[count.index]
    instance_id = "${element(aws_instance.ortest.*.id, floor(count.index / length(var.disk_names)))}"

    lifecycle {
      ignore_changes = [volume_id, instance_id]
    }
}

resource "aws_ebs_volume" "orebs" {
   count             = var.awsprops.count * length(var.disk_names)
   availability_zone = "${var.awsprops.region}b"
   size              = var.disk_sizes[count.index%length(var.disk_names)]
   type              = var.awsprops.volume_type
   iops              = var.disk_iops
  
   tags = {
    Application = "Oracle DB"
    Name        = "Dotmatics-DEV-ORA-DB"
    Created_by     = "TF"
    Environment = "dev"
    Function = "Discovery"
    OS	= "Oracle Linux" 
    Owner	= "Informatics"
    Application_version = "19c"
    Notes = "Development Dotmatics 2022.3 Oracle DB Server - 19c"
    Depends_on = "Dotmatics"
   }

}

# EC2 resource
resource "aws_instance" "ortest" {
  count         = var.awsprops.count
  ami           = var.awsprops.ami
  instance_type = var.awsprops.itype
  subnet_id     = var.awsprops.subnet 
  key_name      = var.awsprops.keyname
  depends_on    = [aws_ebs_volume.orebs]

  root_block_device {
    volume_size = var.awsprops.volume_size
    volume_type = var.awsprops.volume_type
    delete_on_termination = true
    iops = 200 

    tags = {
      Application = "Oracle DB"
      Name        = "Dotmatics-DEV-ORA-DB-${count.index +1}"
      Created_by     = "TF"
      Environment = "dev"
      Function = "Discovery"
      OS	= "Oracle Linux" 
      Owner	= "Informatics"
      Application_version = "19c"
      Notes = "Development Dotmatics 2022.3 Oracle DB Server - 19c"
      Depends_on = "Dotmatics"
    }
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

  connection {
    host  = self.private_ip
    agent = true
    type  = "ssh"
    user  = "ec2-user"
    private_key = file(pathexpand("~/.ssh/dotmaticsdb.pem"))
  }
  
  vpc_security_group_ids = [
    module.security_group.ec2_sg_private
  ]
     
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_ortest.name

  tags = {
    Application = "Oracle DB"
    Name        = "Dotmatics-DEV-ORA-DB-${count.index +1}"
    Created_by     = "TF"
    Environment = "dev"
    Function = "Discovery"
    OS	= "Oracle Linux" 
    Owner	= "Informatics"
    Application_version = "19c"
    Notes = "Development Dotmatics 2022.3 Oracle DB Server - 19c"
    Depends_on = "Dotmatics"
  }

}


resource "null_resource" "oracle_script" {
  count         = var.awsprops.count
  provisioner "remote-exec" {
    inline = [
      "echo $HOME",
      "sudo chmod +x $HOME/${var.shfile}",
      "echo ${aws_instance.ortest[count.index].private_ip} > $HOME/ip_addr",
      "sudo $HOME/${var.shfile} ${var.license} ${var.recovery_date} ${var.sns_topic_arn}",
    ]
    on_failure = fail 
  }

  # Establishes connection to be used by all
  # generic remote provisioners (i.e. file/remote-exec)
  connection {
    host  = aws_instance.ortest[count.index].private_ip
    agent = true
    type  = "ssh"
    user  = "ec2-user"
    private_key = file(pathexpand("~/.ssh/dotmaticsdb.pem"))
  }
  depends_on = [
    aws_volume_attachment.or_ebs_att
  ]
}

module "security_group" {
    source = "./modules/security-groups"
    vpc_id = var.awsprops.vpc
}

