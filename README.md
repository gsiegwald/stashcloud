# Stashcloud – Self-Hosted File Storage

This project deploys a web-based file management application (upload/download) on OVHcloud, using Filestash as the web interface and OVH Object Storage (S3) for file storage.

The infrastructure is automated with Terraform and Ansible.

## Prerequisites
- A local Linux machine with Terraform, Ansible, Docker, Docker Compose, s3cmd, and Git installed (tested versions: Terraform 1.14.3, Ansible 2.10.8, Docker 29.2.0, Docker Compose 5.0.2, s3cmd 2.2.0).
- An OVHcloud account with an active Public Cloud project, and OVH API keys configured.
- A domain name (for HTTPS access, to be configured later).
- An SSH key configured both on the OVHcloud account (for instance access) and on GitHub (for code deployment).

## Architecture (overview)
The target architecture includes:
- An Ubuntu Public Cloud instance (VM) to host Filestash and an Nginx server.
- A Filestash Docker container (web application) accessible through Nginx (which will act as an HTTPS reverse proxy).
- An OVHcloud Object Storage (S3 bucket) to store uploaded files.
- A dedicated IAM user with restricted access to this bucket.
