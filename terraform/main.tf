resource "openstack_compute_keypair_v2" "default_key" {
  name       = "stashcloud_project_key"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}

resource "openstack_compute_instance_v2" "vm_filestash" {
  name        = "vm-filestash-1"
  flavor_name = "b2-7"
  image_name  = "Ubuntu 24.04"
  key_pair    = openstack_compute_keypair_v2.default_key.name

  network { name = "Ext-Net" }
  security_groups = ["default"]

  lifecycle { ignore_changes = [image_id] }
}
