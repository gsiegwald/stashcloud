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


PUBLIC_IP=$(terraform -chdir=terraform/frontend output -raw ec2_public_ip)

# Wait Until SSH is available
until nc -z -w5 "$PUBLIC_IP" 22; do sleep 3; done

# Trust the host key on first connection and store it in known_hosts for all subsequent verifications.
# Residual risk accepted: one-time provisioning, short exposure window, SSH restricted to admin_ip.
ssh-keyscan -H "$PUBLIC_IP" >> ~/.ssh/known_hosts

echo "=== Ansible : Frontend ==="
ansible-playbook -i ansible/inventories/aws_ec2.yaml ansible/playbooks/provision_front.yml

echo "Ready to go!"
EC2_IP=$(terraform -chdir=terraform/frontend output -raw ec2_public_ip)
echo "Access your drive at: https://$(echo $EC2_IP | tr '.' '-').sslip.io"
