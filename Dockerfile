# syntax=docker/dockerfile:1

FROM python:3.12-slim-bookworm@sha256:31c0807da611e2e377a2e9b566ad4eb038ac5a5838cbbbe6f2262259b5dc77a0

ARG TERRAFORM_VERSION=1.14.3
ARG AWSCLI_VERSION=2.33.6
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp/home \
    ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# System packages required by the project scripts
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gnupg \
    openssh-client \
    openssl \
    unzip \
    netcat-openbsd \
    less \
    groff \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform with GPG signature verification of SHA256SUMS
# HashiCorp public key fingerprint:
# C874 011F 0AB4 0511 0D02 1055 3436 5D94 72D7 468F
RUN set -euo pipefail \
    && case "${TARGETARCH}" in \
         amd64) TF_ARCH="amd64" ;; \
         arm64) TF_ARCH="arm64" ;; \
         *) echo "Unsupported TARGETARCH for Terraform: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && TERRAFORM_ZIP="terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip" \
    && curl -fsSLo "/tmp/${TERRAFORM_ZIP}" \
         "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TERRAFORM_ZIP}" \
    && curl -fsSLo /tmp/SHA256SUMS \
         "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && curl -fsSLo /tmp/SHA256SUMS.sig \
         "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig" \
    && curl -fsSLo /tmp/hashicorp.asc \
         "https://www.hashicorp.com/.well-known/pgp-key.txt" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --import /tmp/hashicorp.asc \
    && gpg --batch --with-colons --fingerprint 72D7468F \
         | grep '^fpr:::::::::C874011F0AB405110D02105534365D9472D7468F:' \
    && gpg --batch --verify /tmp/SHA256SUMS.sig /tmp/SHA256SUMS \
    && cd /tmp \
    && grep "${TERRAFORM_ZIP}" SHA256SUMS | sha256sum -c - \
    && unzip -q "/tmp/${TERRAFORM_ZIP}" -d /usr/local/bin \
    && rm -rf "${GNUPGHOME}" \
              /tmp/hashicorp.asc \
              /tmp/SHA256SUMS \
              /tmp/SHA256SUMS.sig \
              "/tmp/${TERRAFORM_ZIP}" \
    && terraform version

# Write AWS CLI public key to disk
# AWS CLI Team public key fingerprint:
# FB5D B77F D5C1 18B8 0511 ADA8 A631 0ACC 4672 475C
RUN cat > /tmp/aws-cli-public-key.asc <<'EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
aGveYQUJDMpiLAAKCRCmMQrMRnJHXKBYD/9Ab0qQdGiO5hObchG8xh8Rpb4Mjyf6
0JrVo6m8GNjNj6BHkSc8fuTQJ/FaEhaQxj3pjZ3GXPrXjIIVChmICLlFuRXYzrXc
Pw0lniybypsZEVai5kO0tCNBCCFuMN9RsmmRG8mf7lC4FSTbUDmxG/QlYK+0IV/l
uJkzxWa+rySkdpm0JdqumjegNRgObdXHAQDWlubWQHWyZyIQ2B4U7AxqSpcdJp6I
S4Zds4wVLd1WE5pquYQ8vS2cNlDm4QNg8wTj58e3lKN47hXHMIb6CHxRnb947oJa
pg189LLPR5koh+EorNkA1wu5mAJtJvy5YMsppy2y/kIjp3lyY6AmPT1posgGk70Z
CmToEZ5rbd7ARExtlh76A0cabMDFlEHDIK8RNUOSRr7L64+KxOUegKBfQHb9dADY
qqiKqpCbKgvtWlds909Ms74JBgr2KwZCSY1HaOxnIr4CY43QRqAq5YHOay/mU+6w
hhmdF18vpyK0vfkvvGresWtSXbag7Hkt3XjaEw76BzxQH21EBDqU8WJVjHgU6ru+
DJTs+SxgJbaT3hb/vyjlw0lK+hFfhWKRwgOXH8vqducF95NRSUxtS4fpqxWVaw3Q
V2OWSjbne99A5EPEySzryFTKbMGwaTlAwMCwYevt4YT6eb7NmFhTx0Fis4TalUs+
j+c7Kg92pDx2uQ==
-----END PGP PUBLIC KEY BLOCK-----
EOF

# Install AWS CLI v2 with PGP signature verification
RUN set -euo pipefail \
    && case "${TARGETARCH}" in \
         amd64) AWSCLI_ARCH="x86_64" ;; \
         arm64) AWSCLI_ARCH="aarch64" ;; \
         *) echo "Unsupported TARGETARCH for AWS CLI: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && AWSCLI_ZIP="awscli-exe-linux-${AWSCLI_ARCH}-${AWSCLI_VERSION}.zip" \
    && AWSCLI_SIG="${AWSCLI_ZIP}.sig" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --import /tmp/aws-cli-public-key.asc \
    && gpg --batch --with-colons --fingerprint A6310ACC4672475C \
         | grep '^fpr:::::::::FB5DB77FD5C118B80511ADA8A6310ACC4672475C:' \
    && curl -fsSLo "/tmp/${AWSCLI_ZIP}" \
         "https://awscli.amazonaws.com/${AWSCLI_ZIP}" \
    && curl -fsSLo "/tmp/${AWSCLI_SIG}" \
         "https://awscli.amazonaws.com/${AWSCLI_SIG}" \
    && gpg --batch --verify "/tmp/${AWSCLI_SIG}" "/tmp/${AWSCLI_ZIP}" \
    && mkdir -p /tmp/awscli-installer \
    && unzip -q "/tmp/${AWSCLI_ZIP}" -d /tmp/awscli-installer \
    && /tmp/awscli-installer/aws/install \
         --bin-dir /usr/local/bin \
         --install-dir /usr/local/aws-cli \
    && rm -rf "${GNUPGHOME}" \
              /tmp/aws-cli-public-key.asc \
              "/tmp/${AWSCLI_ZIP}" \
              "/tmp/${AWSCLI_SIG}" \
              /tmp/awscli-installer \
    && aws --version

# Install Ansible + Python deps required by the AWS dynamic inventory plugin
RUN pip install --no-cache-dir \
    "ansible==10.*" \
    boto3 \
    botocore \
    jmespath

# Install required Ansible collections (pinned)
RUN ansible-galaxy collection install \
    amazon.aws:==10.3.0 \
    community.docker:==5.1.0

# Prepare writable runtime directories
RUN mkdir -p /workspace /tmp/home /tmp/ansible \
 && chmod 1777 /tmp/home /tmp/ansible

WORKDIR /workspace

# By default, run the project entrypoint from the mounted repository
CMD ["./run.sh"]
