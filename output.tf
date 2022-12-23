output "instance_ids" {
  description = "IDs of EC2 instances."
  value       = aws_instance.ortest.*.id
}

output "ec2_private_ip" {
  value = aws_instance.ortest.*.private_ip
}
