#!/bin/bash
set -e

echo "=== Terraform : Frontend destroy ==="
terraform -chdir=terraform/frontend destroy \
  -auto-approve \
  -var-file=../shared.tfvars \
  -var-file=local.tfvars

echo "=== Terraform : Backend destroy ==="
terraform -chdir=terraform/backend destroy \
  -auto-approve \
  -var-file=../shared.tfvars

echo "=== Infrastructure destroyed ==="
