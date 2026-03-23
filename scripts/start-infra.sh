#!/bin/bash
set -e

echo "=== Terraform : Backend ==="
terraform -chdir=terraform/backend init
terraform -chdir=terraform/backend plan
terraform -chdir=terraform/backend apply -auto-approve

echo "=== Terraform : Frontend ==="
terraform -chdir=terraform/frontend init
terraform -chdir=terraform/frontend plan
terraform -chdir=terraform/frontend apply -auto-approve


PUBLIC_IP=$(terraform -chdir=terraform/frontend output -raw ec2_public_ip)

# Wait Until SSH is available
until nc -z -w5 "$PUBLIC_IP" 22; do sleep 3; done

# Trust the host key on first connection and store it in .ssh/known_hosts for all subsequent verifications.
ssh-keyscan -H "$PUBLIC_IP" >> .ssh/known_hosts

echo "=== Ansible : Frontend ==="
ansible-playbook -i ansible/inventories/aws_ec2.yaml ansible/playbooks/provision_front.yml \
  --extra-vars "certbot_email=${CERTBOT_EMAIL}"

echo "Ready to go!"
EC2_IP=$(terraform -chdir=terraform/frontend output -raw ec2_public_ip)
echo "Access your drive at: https://$(echo $EC2_IP | tr '.' '-').sslip.io"
