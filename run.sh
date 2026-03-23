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
# SSH key management
# ─────────────────────────────────────────

# Anchor paths to the script's directory to ensure correct behavior
# regardless of where the script is called from
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_KEY_DIR="${SCRIPT_DIR}/.ssh"
SSH_KEY_PATH="${SSH_KEY_DIR}/stashcloud_key"

mkdir -p "$SSH_KEY_DIR"
chmod 700 "$SSH_KEY_DIR"

if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "stashcloud-deployer"
  chmod 600 "$SSH_KEY_PATH"    # explicit permissions in case of permissive umask
  echo "→ SSH key generated: $SSH_KEY_PATH"
else
  echo "→ Reusing existing SSH key: $SSH_KEY_PATH"
fi

# ANSIBLE_PRIVATE_KEY_FILE overrides private_key_file in ansible.cfg
export TF_VAR_ssh_public_key=$(cat "${SSH_KEY_PATH}.pub")
export ANSIBLE_PRIVATE_KEY_FILE="$SSH_KEY_PATH"
export ANSIBLE_SSH_ARGS="-o UserKnownHostsFile=${SSH_KEY_DIR}/known_hosts"

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
