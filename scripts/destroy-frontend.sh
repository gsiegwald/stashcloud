#!/bin/bash
set -e

echo "=== Terraform : Frontend destroy ==="
terraform -chdir=terraform/frontend destroy \
  -auto-approve \
  -var-file=../shared.tfvars \
  -var-file=local.tfvars

echo "=== Frontend destroyed ==="
