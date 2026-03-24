resource "aws_key_pair" "admin_key" {
  key_name   = "stashcloud-admin-key"
  public_key = var.ssh_public_key
}

data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "stashcloud_ec2" {
  ami                    = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.admin_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.filestash_profile.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    #prevents Docker containers from accessing the IMDS service
    http_put_response_hop_limit = 1
   }

  tags = {
    Name    = "stashcloud_ec2"
    Stack   = "frontend"
    Project = "stashcloud"
  }
}

resource "aws_eip" "stashcloud_eip" {
  tags = {
    Name = "stashcloud_eip"
  }
}

resource "aws_eip_association" "stashcloud_eip_association" {
  allocation_id = aws_eip.stashcloud_eip.id
  instance_id   = aws_instance.stashcloud_ec2.id
}


