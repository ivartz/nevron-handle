terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {}

resource "openstack_compute_servergroup_v2" "anti-affinity-group" {
  name     = "anti-affinity"
  policies = ["anti-affinity"]
  rules {
      max_server_per_host = 1
  }
}

resource "openstack_compute_instance_v2" "large" {
  count = 1
  name = format("work-%02d", count.index + 1)
  image_name = "Ubuntu 22.04"
  flavor_name = "n1.max"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]


  scheduler_hints {
    group = openstack_compute_servergroup_v2.anti-affinity-group.id
  }

  network {
    name = "provider"
  }
}
