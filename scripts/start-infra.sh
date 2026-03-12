#!/bin/bash
set -e

echo "=== Terraform : Backend ==="
terraform -chdir=terraform/backend init -var-file=../shared.tfvars
terraform -chdir=terraform/backend plan -var-file=../shared.tfvars
terraform -chdir=terraform/backend apply -auto-approve -var-file=../shared.tfvars

echo "=== Terraform : Frontend ==="
terraform -chdir=terraform/frontend init -var-file=../shared.tfvars -var-file=local.tfvars
terraform -chdir=terraform/frontend plan -var-file=../shared.tfvars -var-file=local.tfvars
terraform -chdir=terraform/frontend apply -auto-approve -var-file=../shared.tfvars -var-file=local.tfvars

echo "=== Ansible : Frontend ==="
ansible-playbook -i ansible/inventories/aws_ec2.yaml ansible/playbooks/provision_front.yml

echo "Ready to go!"
EC2_IP=$(terraform -chdir=terraform/frontend output -raw ec2_public_ip)
echo "Access your drive at: https://$(echo $EC2_IP | tr '.' '-').sslip.io"
