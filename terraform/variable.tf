# terraform/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "admin_ip" {
  description = "Allowed IP adress for SSH (/32)"
  type        = string
}
