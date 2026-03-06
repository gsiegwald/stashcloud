output "ec2_public_ip" {
  description = "EC2 public IP adress"
  value       = aws_eip.stashcloud_eip.public_ip
}

output "ec2_role_arn" {
  description = "ARN of the IAM role attached to the EC2 instance."
  value       = aws_iam_role.filestash_role.arn
}

output "ec2_instance_profile_arn" {
  description = "ARN of the instance profile attached to the EC2 instance."
  value       = aws_iam_instance_profile.filestash_profile.arn
}

output "ec2_role_name" {
  description = "IAM role name."
  value       = aws_iam_role.filestash_role.name
}
