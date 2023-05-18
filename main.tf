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
    Name        = "oracle_db"
    Created_by     = "TF"
    Environment = "Development"
    Retention	= "DO NOT DELETE - DEVELOPMENT SERVER"
    Backup	= "2Days"
    Function = "Discovery"
    OS	= "Linux" 
    Owner	= "Informatics"
    Application_Version = "2022.3"
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
    count = length(var.disk_names)
    device_name = "${var.disk_names[count.index]}"
    volume_id   = "${element(aws_ebs_volume.orebs.*.id, count.index)}"
    instance_id = "${element(aws_instance.ortest.*.id, count.index)}"
}

resource "aws_ebs_volume" "orebs" {
   count             = length(var.disk_names)
   availability_zone = "${var.awsprops.region}b"
   size              = var.disk_sizes[count.index]
   type              = var.awsprops.volume_type
   iops              = var.disk_iops[count.index]
  
   tags = {
    Application = "Oracle"
    Name        = "oracle_db_ebs_${count.index +1}"
    Created_by     = "TF"
    Environment = "Development"
    Retention	= "DO NOT DELETE - DEVELOPMENT SERVER"
    Backup	= "2Days"
    Function = "Discovery"
    OS	= "Linux" 
    Owner	= "Informatics"
    Application_Version = "2022.3"
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
    iops = element(var.disk_iops, 1)
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
    Application = "Oracle"
    Name        = "oracle_db_ec2_${count.index +1}"
    Created_by     = "TF"
    Environment = "Development"
    Retention	= "DO NOT DELETE - DEVELOPMENT SERVER"
    Backup	= "2Days"
    Function = "Discovery"
    OS	= "Linux" 
    Owner	= "Informatics"
    Application_Version = "2022.3"
  }

  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
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

