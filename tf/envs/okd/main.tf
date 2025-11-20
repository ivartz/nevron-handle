terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {}

resource "openstack_compute_instance_v2" "large" {
  count = 1
  name = format("large-%02d", count.index + 1)
  image_name = "Ubuntu 22.04"
  flavor_name = "n2.openshiftcontroller"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]

  network {
    name = "provider"
  }
}
