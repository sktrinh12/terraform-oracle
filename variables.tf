variable "awsprops" {
    type = map
    default = {
    count = 2
    region = "us-west-2"
    ami = "ami-0bf3b3e2db4302789" // OL7.9-x86_64-HVM-2020-12-07
    vpc = "vpc-031ebba25c9df51eb"
    itype = "r4.large"
    subnet = "subnet-086ffcb03661d67a2"
    publicip = false
    keyname = "eks-apps" 
    volume_size =  250
    volume_type = "gp3"
  }
}

variable "bkpfile" {
    type = string
    default = "full_backup.sh"
}

variable "shfile" {
    type = string 
    default = "oracle_install.sh"
}

variable "license" {
    type = string
    default = "FILL_IN_AT_RUNTIME"
}

variable "recovery_date" {
    type = string
    default = "newest"
}
