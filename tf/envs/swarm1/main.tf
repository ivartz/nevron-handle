terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {}

resource "openstack_compute_instance_v2" "work1" {
  count = 40
  name = format("work1-%02d", count.index + 1)
  image_name = "Ubuntu 22.04"
  flavor_name = "n1.work1"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]

  network {
    name = "provider"
  }
}
