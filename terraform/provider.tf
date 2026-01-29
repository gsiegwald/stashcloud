# terraform/provider.tf
terraform {
  required_providers {
    ovh = {
      source = "ovh/ovh"
      version = "~> 2.1" 
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
      version = "~> 1.52"
    }
  }
}
provider "ovh" {}

provider "openstack" {}
