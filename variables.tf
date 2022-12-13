variable "awsprops" {
    type = map
    default = {
    region = "us-west-2"
    ami = "ami-0bf3b3e2db4302789" // OL7.9-x86_64-HVM-2020-12-07
    vpc = "vpc-031ebba25c9df51eb"
    itype = "t3.medium"
    subnet = "subnet-086ffcb03661d67a2"
    publicip = false
    keyname = "eks-apps" 
    volume_size =  100
    volume_type = "gp3"
    # csv_file = "security_files/aws_credentials.csv"
    
  }
}
