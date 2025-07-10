terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {}

resource "openstack_compute_instance_v2" "test-server" {
  name = "test-server"
  image_name = "Ubuntu 22.04"
  flavor_name = "m1.small"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]

  network {
    name = "provider"
  }
}
