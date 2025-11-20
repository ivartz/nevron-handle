terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
    }
  }
}

provider "openstack" {}

resource "openstack_compute_servergroup_v2" "group-micro" {
  name     = "anti-affinity"
  policies = ["anti-affinity"]
  rules {
      max_server_per_host = 4
  }
}

resource "openstack_compute_servergroup_v2" "group-work1" {
  name     = "anti-affinity"
  policies = ["anti-affinity"]
  rules {
      max_server_per_host = 8
  }
}

resource "openstack_compute_instance_v2" "micro" {
  count = 16
  name = format("micro-%02d", count.index + 1)
  image_name = "Ubuntu 22.04"
  flavor_name = "n1.micro"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]

  scheduler_hints {
    group = openstack_compute_servergroup_v2.group-micro.id
  }

  network {
    name = "provider"
  }
}

resource "openstack_compute_instance_v2" "work1" {
  count = 32
  name = format("work1-%02d", count.index + 1)
  image_name = "Ubuntu 22.04"
  flavor_name = "n1.work1"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]


  scheduler_hints {
    group = openstack_compute_servergroup_v2.group-work1.id
  }

  network {
    name = "provider"
  }
}
