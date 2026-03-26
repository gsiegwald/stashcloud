#!/bin/bash
set -e

# ─────────────────────────────────────────
# Usage
# ─────────────────────────────────────────

# ./destroy.sh           → destroys full infrastructure (frontend + backend)
# ./destroy.sh frontend  → destroys frontend only
# ./destroy.sh backend   → destroys backend only

MODE="${1:-all}"

if [ "$MODE" != "all" ] && [ "$MODE" != "frontend" ] && [ "$MODE" != "backend" ]; then
  echo "Usage: $0 [frontend|backend|all]"
  echo "  frontend : destroy frontend infrastructure only"
  echo "  backend  : destroy backend infrastructure only"
  echo "  all      : destroy full infrastructure (default)"
  exit 1
fi

# ─────────────────────────────────────────
# Load saved variables from state file
# ─────────────────────────────────────────

STATE_FILE=".stashcloud-state"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: .stashcloud-state not found. Has the infrastructure been deployed?"
  exit 1
fi

BUCKET_NAME=$(grep "^bucket_name=" "$STATE_FILE" | cut -d= -f2)
export TF_VAR_bucket_name="$BUCKET_NAME"
echo "→ Bucket: $BUCKET_NAME"

AWS_REGION=$(grep "^aws_region=" "$STATE_FILE" | cut -d= -f2)
export TF_VAR_aws_region="$AWS_REGION"
export AWS_DEFAULT_REGION="$AWS_REGION"
echo "→ Region: $AWS_REGION"

# ─────────────────────────────────────────
# SSH key (required by Terraform variables)
# ─────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_KEY_PATH="${SCRIPT_DIR}/../.ssh/stashcloud_key"


if [ ! -f "${SSH_KEY_PATH}.pub" ]; then
  echo "Error: SSH key not found at ${SSH_KEY_PATH}.pub"
  echo "Has the infrastructure been deployed with run.sh?"
  exit 1
fi

export TF_VAR_ssh_public_key=$(cat "${SSH_KEY_PATH}.pub")
echo "→ SSH key loaded: ${SSH_KEY_PATH}.pub"

# ─────────────────────────────────────────
# Admin IP detection (required for frontend)
# ─────────────────────────────────────────

if [ "$MODE" = "all" ] || [ "$MODE" = "frontend" ]; then
  echo "→ Detecting public IP address..."

  PUBLIC_IP=$(curl -sf --max-time 5 https://ifconfig.me \
    || curl -sf --max-time 5 https://api.ipify.org \
    || { echo "Error: could not detect public IP address."; exit 1; })

  export TF_VAR_admin_ip="${PUBLIC_IP}/32"
  echo "→ Admin IP set to: ${PUBLIC_IP}/32"
fi

# ─────────────────────────────────────────
# Destroy
# ─────────────────────────────────────────

if [ "$MODE" = "all" ] || [ "$MODE" = "frontend" ]; then
  echo "=== Terraform : Frontend destroy ==="
  terraform -chdir=terraform/frontend destroy \
    -auto-approve
  echo "=== Frontend destroyed ==="
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "backend" ]; then
  echo "=== Terraform : Backend destroy ==="
  terraform -chdir=terraform/backend destroy \
    -auto-approve
  echo "=== Backend destroyed ==="
fi

echo "=== Done ==="

# ─────────────────────────────────────────
# Cleanup local state
# ─────────────────────────────────────────

# Remove state file when the bucket is destroyed (full or backend destroy)
# Keep it when only the frontend is destroyed (bucket still exists)
if [ "$MODE" = "all" ] || [ "$MODE" = "backend" ]; then
  rm -f "$STATE_FILE"
  echo "→ Local state file deleted"
fi
