# Stashcloud – Lightweight Cloud Storage Manager

This project deploys a web-based file management application on AWS, using Filestash as the web interface and Amazon S3 (Object Storage) for file storage.

The infrastructure is automated with Terraform and Ansible.

## Prerequisites

## Prerequisites

* Local workstation (Linux) with the following tools installed:

  * Terraform (tested: 1.14.3)
  * Ansible (tested: 2.10.8)
  * AWS CLI (tested: 2.33.12)
  * Git
  * Python 3 + pip (recommended to use a virtualenv)

* Python dependencies on the control node (your local machine), required for the AWS dynamic inventory:

  * `boto3`
  * `botocore`

* Ansible collections :

  * `amazon.aws` (AWS EC2 dynamic inventory plugin)
  * `community.docker` (Docker Compose v2 module)

  Example:

  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install boto3 botocore
  ansible-galaxy collection install amazon.aws community.docker
  ```

* AWS account access

  * An AWS account with programmatic access enabled via either:

    * an Access Key ID / Secret Access Key configured on your workstation (`aws configure`)

* SSH keypair

  * A local SSH key (private key stored on your workstation, e.g. `~/.ssh/id_ed25519`)
  * The matching public key available for EC2 key-pair creation 

* Network access

  * Outbound HTTPS access from your workstation to AWS APIs (Terraform + Ansible inventory)
  * Ability to reach the EC2 instance over:

    * SSH (22) from your local IP
    * HTTP (80) from your browser (HTTPS 443 will be added later)

## Architecture 
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

```text
stashcloud/
├─ .git/                         
├─ .gitignore                    # Ignore Terraform state/cache and any *.tfvars secrets
├─ README.md
├─ docker
│  ├─ docker-compose.yml
│  └─ nginx.conf                     
├─ ansible/                      
│  ├─ ansible.cfg                # Ansible settings
│  ├─ inventories/
│  │  └─ aws_ec2.yaml            # Dynamic inventory (AWS EC2 plugin) + host compose
│  ├─ group_vars/                # Group variables split by host groups
│  │  ├─ backend/
│  │  │  └─ main.yml             # Variables for backend hosts
│  │  └─ frontend/
│  │     └─ main.yml             # Variables for frontend hosts
│  ├─ playbooks/
│  │  ├─ provision_back.yml      # Backend provisioning playbook
│  │  ├─ provision_front.yml     # Frontend provisioning playbook
│  │  └─ site.yml                # Main entrypoint playbook (orchestrates roles/plays)
│  └─ roles/
│     └─ base/
│        ├─ handlers/
│        │  └─ main.yml          
│        └─ tasks/
│           └─ main.yml          # Base tasks (updates, Docker install, etc.)
└─ terraform/                    
   ├─ main.tf                    # Provider block, network, security group, EC2 resources
   ├─ variable.tf                # Input variables (aws_region, admin_ip, etc.)
   └─ .terraform.lock.hcl        
 
Note: terraform/terraform.tfstate* and terraform/.terraform/ exist locally but are intentionally ignored by Git for security concerns.
```

## Provisionning

### Provisioning Workflow (Terraform + Ansible)
```mermaid
---
config:
  layout: default
---
flowchart TB
  subgraph L["Local"]
    U["Admin workstation"]
    TF["Terraform local"]
    ANS["Ansible local"]
  end

  subgraph CP["AWS APIs"]
    VPCAPI["VPC API"]
    EC2API["EC2 API"]
  end

  subgraph DP["AWS Resources"]
    VPC["VPC / Subnets / Internet Gateway / Route Tables"]
    SG["Security Group"]
    EC2["EC2 instance stashcloud_ec2\nUbuntu"]
  end

  subgraph APP["Service"]
    OS["OS provisioning"]
    DOCKER["Docker Engine"]
    CT["Application container"]
    EP["Service endpoints <br>HTTP and HTTPS"]
  end

  U --> TF & ANS
  TF -- AWS API over HTTPS --> VPCAPI & EC2API
  VPCAPI --> VPC
  EC2API --> SG & EC2
  SG --- EC2
  ANS -- Query inventory by tags --> EC2API
  EC2API -- Return public IP --> ANS
  ANS -- SSH with key --> EC2
  EC2 --> OS --> DOCKER --> CT --> EP
  B["User / Browser"] -- HTTP or HTTPS --> EP
```

### Runbook
```bash
#Creates infrastructure
cd ~/stashcloud/terraform
terraform init
terraform plan
terraform apply

#Instances installs and configuration
ansible-playbook -i ansible/inventories/aws_ec2.yaml playbooks/provision_front.yml
```

## Security

### SSH access

Connect using your private key and the instance public IP from Terraform:

```bash
cd ~/stashcloud/terraform
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
