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

resource "openstack_compute_servergroup_v2" "group-large" {
  name     = "anti-affinity"
  policies = ["anti-affinity"]
  rules {
      max_server_per_host = 1
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

resource "openstack_compute_instance_v2" "large" {
  count = 4
  name = format("large-%02d", count.index + 1)
  image_name = "Ubuntu 22.04"
  flavor_name = "n1.large"

  config_drive = true

  key_pair = "ms5"
  security_groups = [ "default", "SSH-ICMP" ]


  scheduler_hints {
    group = openstack_compute_servergroup_v2.group-large.id
  }

  network {
    name = "provider"
  }
}
