# Stashcloud – Lightweight Cloud Storage Manager

Stashcloud is a lightweight, self-hosted shared drive for teams, families, or groups of friends.

It lets you manage files from a web browser without relying on Google Drive/Dropbox-like services or sharing storage access credentials with end users.

Using Filestash as the web interface and an S3 bucket as the file repository, the stack is provisioned end-to-end securely with Terraform + Ansible.



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
  * `jmespath`

* Ansible collections :

  * `amazon.aws` (AWS EC2 dynamic inventory plugin)
  * `community.docker` (Docker Compose v2 module)

  Example :

  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -U pip
  pip install boto3 botocore jmespath
  ansible-galaxy collection install amazon.aws community.docker
  ```

 * An AWS account with programmatic access enabled via an Access Key ID / Secret Access Key configured on your workstation (`aws configure`)

* The AWS credentials used on the workstation must allow managing VPC/EC2/EIP, S3, IAM (roles/policies/instance profiles) and CloudWatch Logs

* No AWS static keys are required on the EC2 instance: access to S3 and CloudWatch Logs is provided via the EC2 instance profile (IAM role) and IMDSv2.

*  A local SSH key (private key stored on your workstation, e.g. `~/.ssh/id_ed25519`)

* Network access :

  * Outbound HTTPS access from your workstation to AWS APIs (Terraform + Ansible inventory)
  * Ability to reach the EC2 instance over SSH (22) and HTTP (80) (HTTPS 443 will be added later)

## Architecture 
High-level view of the target architecture and the main network flows between the client, the Filestash VM, and the S3-compatible Object Storage bucket.

```mermaid
flowchart LR
  %% Infrastructure
  subgraph AWS["AWS"]
    subgraph EC2["EC2 Ubuntu"]
      NGINX["Nginx reverse proxy (Docker)"]
      FS["Filestash (Docker)"]
    end
    S3["Amazon S3 bucket"]
    CWL["CloudWatch Logs<br/>Log Group: /stashcloud/containers"]
  end

  %% Network flows
  User["Client"] -->|SSH 22| EC2
  User -->|HTTP 80 / HTTPS 443| NGINX
  NGINX -->|HTTP 8334| FS
  FS -->|S3 API| S3

  %% Centralized logging flows
  NGINX -->|Logs over HTTPS - awslogs driver| CWL
  FS -->|Logs over HTTPS - awslogs driver| CWL

  %% ---- Subgraph styling (backgrounds) ----
  style AWS fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
  style EC2 fill:#F3F4F6,stroke:#CBD5E1,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold

  %% ---- Node styling ----
  classDef default  fill:#E8F1FF,stroke:#2563EB,stroke-width:1px,color:#111827;
  classDef fileNode fill:#F3E8FF,stroke:#7C3AED,stroke-width:1px,color:#111827;
```

The target architecture includes:

* An Ubuntu Public Cloud instance (VM) to host Filestash and an Nginx server.
* A Filestash Docker container (web application) accessible through Nginx (which will act as an HTTPS reverse proxy).
* An Amazon S3 bucket to store uploaded files.
* Centralized logging to Amazon CloudWatch Logs for both Nginx and Filestash (Docker `awslogs` log driver).

## Repository structure

```text

stashcloud/
├── .git/
├── .gitignore                  # ignore state files, secrets, etc.
├── README.md
├── ansible.cfg                 # global Ansible configuration
├── docker/
│   ├── docker-compose.yml
│   └── nginx.conf
├── ansible/
│   ├── inventories/
│   │   └── aws_ec2.yaml        # dynamic inventory (AWS plugin)
│   ├── group_vars/
│   │   ├── backend/
│   │   │   └── main.yml        # variables for backend hosts
│   │   └── frontend/
│   │       └── main.yml        # variables for frontend hosts
│   ├── playbooks/
│   │   ├── provision_back.yml  # provision S3
│   │   ├── provision_front.yml # provision Filestash + Nginx
│   │   └── site.yml
│   └── roles/
│       ├── base/               # OS hardening + Docker install
│       │   ├── files/
│       │   ├── handlers/
│       │   │   └── main.yml
│       │   └── tasks/
│       │       └── main.yml
│       └── frontend/           # Filestash & Nginx deployment
│           ├── files/
│           ├── handlers/
│           └── tasks/
│               └── main.yml
└── terraform/
    ├── backend/                # S3 bucket + IAM policy
    │   ├── s3.tf
    │   ├── iam.tf
    │   └── variables.tf
    ├── frontend/               # VPC + EC2 + IAM role/profile + CloudWatch logs
    │   ├── main.tf
    │   ├── iam.tf
    │   ├── logs.tf
    │   ├── remote_state.tf     # read backend outputs (bucket ARN, policy ARN)
    │   ├── variable.tf
    │   └── local.tfvars.example# local admin IP 
    └── shared.tfvars.example   # shared variables across Terraform stacks
```
Note: 
* terraform/*/terraform.tfstate* and terraform/*/.terraform/ exist locally but are intentionally ignored by Git for security concerns.

* terraform/shared.tfvars and terraform/frontend/local.tfvars are intentionally kept local-only for security concerns. The repository includes *.tfvars.example files (terraform/shared.tfvars.example, terraform/frontend/local.tfvars.example) as templates to document the required variables.


## Provisionning

### Terraform Workflow :

```mermaid
flowchart TB
  subgraph L[" Local "]
    U["Admin workstation"]
    TF["Terraform local"]
    TFB["Terraform apply<br/>terraform/backend"]
    TFF["Terraform apply<br/>terraform/frontend"]
  end

  subgraph BK["AWS Resources : Backend"]
    direction TB
    BKRES["Backend resources"]
    S3B["S3 bucket (backend)"]
    S3POL["IAM policy (S3 access)"]
  end

  subgraph FR["AWS Resources : Frontend"]
    direction TB
    FRRES["Frontend resources"]
    VPC["VPC / Subnets / Internet Gateway / Route Tables"]
    SG["Security Group"]
    IAMROLE["IAM role (EC2)"]
    IAMPF["Instance profile"]
    LOGPOL["IAM policy (CloudWatch Logs)"]
    CWLG["CloudWatch Logs<br/>Log Group: /stashcloud/containers"]
    EC2["EC2 instance stashcloud_ec2\nUbuntu"]
  end

  U --> TF
  TF --> TFB
  TF -- "backend already provisioned" --> TFF

  TFB -- "apply backend" --> BKRES
  BKRES -- "create" --> S3B
  BKRES -- "create" --> S3POL

  TFB -- "terraform_remote_state outputs" --> TFF

  TFF -- "apply frontend" --> FRRES
  FRRES -- "create" --> VPC
  FRRES -- "create" --> SG
  FRRES -- "create" --> EC2
  FRRES -- "create" --> IAMROLE
  FRRES -- "create" --> IAMPF
  FRRES -- "create" --> LOGPOL
  FRRES -- "create" --> CWLG

  SG -- "attach" --> EC2
  IAMROLE -- "associate" --> IAMPF -- "attach" --> EC2
  S3POL -- "attach policy" --> IAMROLE
  LOGPOL -- "attach policy" --> IAMROLE

%% ---- Subgraph styling (backgrounds) ----
style L  fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
style BK fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
style FR fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
%% ---- Node styling ----
classDef fileNode fill:#F3E8FF,stroke:#7C3AED,stroke-width:1px,color:#111827;
classDef default  fill:#E8F1FF,stroke:#2563EB,stroke-width:1px,color:#111827;
classDef anchorNode fill:transparent,stroke:transparent,stroke-width:0px,color:transparent;
```

### Ansible Workflow :

```mermaid
flowchart TB
  subgraph L[" Local "]
    U["Admin workstation"]
    ANS["Ansible local"]
    DC["docker/docker-compose.yml"]
    NC["docker/Nginx.conf"]
  end

  subgraph FR["AWS Resources : Frontend"]
    direction TB

    EC2["EC2 instance stashcloud_ec2\nUbuntu"]
  end

  subgraph APP["Service  "]
    OS["OS updates"]
    DOCKER["Docker Engine + Compose v2"]
    ST["stashnet (Docker network)"]
    NGX["Nginx container"]
    FLS["Filestash container"]
    EP["Service endpoints <br>HTTP and HTTPS"]
    OPT["/opt/stashcloud/docker-compose.yml
    /opt/stashcloud/Nginx.conf"]
  end

  U --> ANS

  ANS -- "query IP" <--> FR


  ANS -- "SSH with key" --> EC2

  ANS -- "copy compose + Nginx.conf" --> OPT
  DC --> ANS
  NC --> ANS

  EC2 --> OS --> DOCKER --> ST
  ST --> NGX --> EP
  ST --> FLS
  B["User / Browser"] -- HTTP or HTTPS --> EP
  DOCKER -. "docker compose reads config" .-> OPT

%% ---- Subgraph styling (backgrounds) ----
style L  fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
style FR fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
style APP fill:#F3F4F6,stroke:#949494,stroke-width:1px,color:#111827,font-size:15px,font-weight:bold
%% ---- Node styling ----
classDef fileNode fill:#F3E8FF,stroke:#7C3AED,stroke-width:1px,color:#111827;
classDef default  fill:#E8F1FF,stroke:#2563EB,stroke-width:1px,color:#111827;
classDef anchorNode fill:transparent,stroke:transparent,stroke-width:0px,color:transparent;

%% Apply file style to file nodes
class DC,NC,OPT fileNode;
```

### Runbook :

> **Note**: run the following commands from the repository root (`~/stashcloud`).

#### 1) Provision backend infrastructure (Terraform)

```bash
terraform -chdir=terraform/backend init -var-file=../shared.tfvars 
terraform -chdir=terraform/backend plan -var-file=../shared.tfvars 
terraform -chdir=terraform/backend apply -var-file=../shared.tfvars 
```

#### 2) Provision frontend infrastructure (Terraform)

```bash
terraform -chdir=terraform/frontend init  -var-file=../shared.tfvars -var-file=local.tfvars
terraform -chdir=terraform/frontend plan  -var-file=../shared.tfvars -var-file=local.tfvars
terraform -chdir=terraform/frontend apply  -var-file=../shared.tfvars -var-file=local.tfvars
```

Get EC2 public IP :

```bash
terraform -chdir=terraform/frontend output -raw ec2_public_ip
```

#### 3) Configure the instance and deploy the frontend stack (Ansible)

This playbook:

* updates the OS packages,
* installs Docker Engine and the Docker Compose v2 plugin,
* copies `docker/docker-compose.yml` and `docker/nginx.conf` to `/opt/stashcloud/`,
* deploys (or redeploys) the Filestash + Nginx stack using `docker compose`.

```bash
ansible-playbook -i ansible/inventories/aws_ec2.yaml ansible/playbooks/provision_front.yml
```

#### 4) If needed : Delete the frontend and backend infrastructures

```bash
terraform -chdir=terraform/frontend destroy -var-file=../shared.tfvars -var-file=local.tfvars

terraform -chdir=terraform/backend destroy -var-file=../shared.tfvars
```


### Validate the deployment :

#### 1) From your local machine

Test access to the remote instance via http :
```bash
curl -v http://$(terraform -chdir=terraform output -raw ec2_public_ip)/
```

Connect using your private key and the instance public IP obtained from Terraform :

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@$(terraform -chdir=terraform/frontend output -raw ec2_public_ip)
```

#### 2) From the EC2 instance

```bash
# Containers
sudo docker ps

# Logs
sudo docker logs filestash
sudo docker logs nginx
```

If you need a clean restart within the instance:

```bash
sudo docker compose -f /opt/stashcloud/docker-compose.yml down
sudo docker compose -f /opt/stashcloud/docker-compose.yml up -d
```

## Filestash setup (admin, users, S3 backend connection)

### 1) Open the Filestash admin console

1. In a web browser, open:
   `http://<EC2_PUBLIC_IP>/admin/setup`

2. Set the Filestash admin password (see below)

![Filestash admin password setup](docs/screenshots/admin_password_filestash.png)

If the admin password is already configured, open:
`http://<EC2_PUBLIC_IP>/admin`
and sign in with the admin password.

---

### 2) Configure S3 as the storage backend

1. In the admin console, go to the Storage configuration (left panel).
2. Select S3 as storage backend, remove others if needed (see below)

![Select S3 storage backend](docs/screenshots/choose_storage_backend_filestash.png)

---

### 3) Create Filestash users

Under `Authentification Middleware`, select `HTPASSWD` , fefine a username and password for each user who will access the drive.

![User credentials setup](docs/screenshots/user_credentials_setup_filestash.png)
---

### 4) Connect the S3 bucket

You will need the S3 access credentials and the IAM role information used by the instance.

**Get the S3 Access Key and Secret Key (if applicable):**

```bash
cat ~/.aws/credentials
```

**Get the AWS region**

```bash
cat terraform/shared.tfvars
```

**Get the EC2 IAM role ARN:**

```bash
terraform -chdir=terraform/frontend output -raw ec2_role_arn
```
In the box `Attribute Mapping`, enter the required S3 settings (access and secret key, AWS region, IAM role ARN).

![S3 bucket connection settings](docs/screenshots/S3_connection_configuration_filestash.png)
---

### 5) Sign in as a user

1. Go back to the Filestash login page:
   `http://<EC2_PUBLIC_IP>/`
2. Sign in using one of the user accounts created earlier to access the file manager interface.

## Security

### Measures already in place

* **SSH restricted to `admin_ip` via the Security Group** (port 22 allowed only from your /32).
* **No password authentication**: the Ubuntu image uses key-based SSH only by default.
* **IMDSv2 enforced**: instance metadata access requires a session token (no IMDSv1).
* **No static AWS keys on the EC2 instance**: access to AWS services is provided through an IAM Role
* **Least-privilege IAM policies**:

  * **S3 access policy** (created by the *backend* stack) grants only the required permissions on the dedicated bucket (e.g., list/read/write objects), and is attached to the EC2 role by the *frontend* stack.
  * **CloudWatch Logs policy** (created by the *frontend* stack) grants only the required permissions to publish container logs to CloudWatch Logs.
* **Centralized logging to CloudWatch Logs**: Nginx and Filestash containers use the Docker `awslogs` driver to ship logs over HTTPS to the log group `/stashcloud/containers` (log group managed by Terraform).

## Current project status

* A t3.micro instance on Amazon Web Services (region eu-west-3, Paris) is up and running with Ubuntu 24.04 LTS.
* The VM resides in a dedicated VPC public subnet and is reachable via its public IPv4; SSH access is restricted to your `admin_ip` by the security-group rule.
* This instance will host the Filestash application later, to be deployed with Docker/Ansible.
