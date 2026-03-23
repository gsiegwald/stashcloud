variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "admin_ip" {
  description = "Allowed IP address for SSH (/32)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
}
