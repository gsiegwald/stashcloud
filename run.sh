#!/bin/bash
set -e

# ─────────────────────────────────────────
# AWS region
# ─────────────────────────────────────────

read -p "AWS region [eu-west-3]: " INPUT_REGION
AWS_REGION="${INPUT_REGION:-eu-west-3}"

export TF_VAR_aws_region="$AWS_REGION"
export AWS_DEFAULT_REGION="$AWS_REGION"
echo "→ Region set to: $AWS_REGION"

# ─────────────────────────────────────────
# Let's Encrypt email
# ─────────────────────────────────────────

read -p "Email (required for Let's encrypt certificate):" CERTBOT_EMAIL

if [ -z "$CERTBOT_EMAIL" ]; then
  echo "Error: email is required for Let's Encrypt certificate."
  exit 1
fi

export CERTBOT_EMAIL
echo "→ Email set to: $CERTBOT_EMAIL"

# ─────────────────────────────────────────
# S3 bucket name management
# ─────────────────────────────────────────

STATE_FILE=".stashcloud-state"

if [ -f "$STATE_FILE" ]; then
  # State file exists: reuse the previously generated bucket name
  BUCKET_NAME=$(grep "^bucket_name=" "$STATE_FILE" | cut -d= -f2)
  echo "→ Reusing existing bucket: $BUCKET_NAME"
else
  # First run: generate a unique bucket name and save region
  BUCKET_SUFFIX=$(openssl rand -hex 4)
  BUCKET_NAME="stashcloud-${BUCKET_SUFFIX}"

  # Save bucket name and region for subsequent runs
  echo "bucket_name=${BUCKET_NAME}" > "$STATE_FILE"
  echo "aws_region=${AWS_REGION}" >> "$STATE_FILE"
  echo "→ Generated bucket name: $BUCKET_NAME"
fi

# Export the variable so Terraform reads it via TF_VAR_bucket_name
export TF_VAR_bucket_name="$BUCKET_NAME"

# ─────────────────────────────────────────
# Admin IP detection
# ─────────────────────────────────────────

echo "→ Detecting public IP address..."

PUBLIC_IP=$(curl -sf --max-time 5 https://ifconfig.me \
  || curl -sf --max-time 5 https://api.ipify.org \
  || { echo "Error: could not detect public IP address."; exit 1; })

export TF_VAR_admin_ip="${PUBLIC_IP}/32"
echo "→ Admin IP set to: ${PUBLIC_IP}/32"

# ─────────────────────────────────────────
# Start deployment
# ─────────────────────────────────────────

./scripts/start-infra.sh
