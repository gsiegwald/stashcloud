#!/bin/bash
set -e

echo "=== Backend ==="
terraform -chdir=terraform/backend init -var-file=../shared.tfvars
terraform -chdir=terraform/backend plan -var-file=../shared.tfvars
terraform -chdir=terraform/backend apply -auto-approve -var-file=../shared.tfvars

echo "=== Frontend ==="
terraform -chdir=terraform/frontend init -var-file=../shared.tfvars -var-file=local.tfvars
terraform -chdir=terraform/frontend plan -var-file=../shared.tfvars -var-file=local.tfvars
terraform -chdir=terraform/frontend apply -auto-approve -var-file=../shared.tfvars -var-file=local.tfvars

echo "Ready to go!"
