# Stashcloud – Lightweight Cloud Storage Manager

This project deploys a web-based file management application on AWS, using Filestash as the web interface and Amazon S3 (Object Storage) for file storage.

The infrastructure is automated with Terraform and Ansible.

## Prerequisites
- A local Linux machine with Terraform, Ansible, Docker, Docker Compose, s3cmd, and Git installed (tested versions: Terraform 1.14.3, Ansible 2.10.8, Docker 29.2.0, Docker Compose 5.0.2, aws-cli 2.33.12).
- An OVHcloud account with an active Public Cloud project, and OVH API keys configured.
- A domain name (for HTTPS access, to be configured later).
- An Amazon Web Services account with programmatic access enabled (Access Key ID and Secret Access Key) or an IAM role usable by Terraform.
- An SSH public key registered in the account for EC2 key-pair creation, with the matching private key stored on your local workstation for SSH access.

## Architecture (overview)
High-level view of the target architecture and the main network flows between the client, the Filestash VM, and the S3-compatible Object Storage bucket.

```mermaid
graph LR
  %% -------- Infrastructure --------
  subgraph "AWS (eu-west-3)"
    EC2["EC2 Ubuntu<br/>Filestash Server<br/><i>(public subnet)</i>"]
    S3["Amazon&nbsp;S3<br/>Bucket"]
  end

  %% -------- Flow --------
  UserPC["Client (Browser/SSH)"] -->|SSH&nbsp;22| EC2
  UserPC -->|HTTP/HTTPS&nbsp;80/443| EC2
  EC2 -->|S3&nbsp;API| S3
```


The target architecture includes:
- An Ubuntu Public Cloud instance (VM) to host Filestash and an Nginx server.
- A Filestash Docker container (web application) accessible through Nginx (which will act as an HTTPS reverse proxy).
- An Amazon S3 bucket to store uploaded files.


## Repository structure
Current project layout (Sprint 1):

```text
stashcloud/
├─ .git/                       # Git repository metadata
├─ .gitignore                  # Ignore Terraform state/cache and any *.tfvars secrets
├─ README.md                   # Project overview and updated AWS instructions
└─ terraform/                  # Terraform configuration
   ├─ main.tf                  # Provider block, network, security group, EC2 resources
   ├─ variables.tf             # Input variables (aws_region, admin_ip)
   ├─ terraform.tfvars         # Local-only values (admin_ip) – NOT committed
   └─ .terraform.lock.hcl      # Provider version locks

 
Note: terraform/terraform.tfstate* and terraform/.terraform/ exist locally but are intentionally ignored by Git for security concerns.
```

## Security

### SSH access

Connect using your private key and the instance public IP from Terraform:

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@$(terraform output -raw ec2_public_ip)
```

### Measures already in place

* SSH restricted to `admin_ip` via the security group (port 22 allowed only from your /32).
* No password authentication: the Ubuntu image uses key-based SSH only by default.
* IMDSv2 enforced: metadata access requires a session token.

## Current project status

* A t3.micro instance on Amazon Web Services (region eu-west-3, Paris) is up and running with Ubuntu 24.04 LTS.
* The VM resides in a dedicated VPC public subnet and is reachable via its public IPv4; SSH access is restricted to your `admin_ip` by the security-group rule.
* This instance will host the Filestash application later, to be deployed with Docker/Ansible.


test
