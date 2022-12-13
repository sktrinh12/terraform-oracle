locals {
  tags = {
    created_by = "terraform"
  }
  
  # csv_content = csvdecode(file("${path.module}/../../${var.awsprops.csv_file}"))
  # aws_ecr_url = "${local.csv_content[count.index]["Access key"]}.dkr.ecr.${var.awsprops.region}.amazonaws.com"
}
