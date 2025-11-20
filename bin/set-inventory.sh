#!/bin/bash
: '
Set correct VCPU and MEMORY_MB inventory
for nevron-compute-01,2,3,4

The max_unit and total values are set to the max values allowed
with allocation ratio != 1.0 according to:

MAX VCPU = 16*4 = 64
MAX MEMORY_MB = 1.5*(7824-512) = 10968

Disk remains unchanged according to
the default allocation ratio 1.0:
MAX DISK_GB = 1*106 = 106
'
source ~/api/admin-openrc

while read row
do
  uuid=$(echo $row | cut -d ' ' -f 1)
  echo $row
  openstack resource provider inventory set $uuid --resource VCPU:allocation_ratio=16.0 --resource VCPU:max_unit=64 --resource VCPU:total=64 --resource MEMORY_MB:allocation_ratio=1.5 --resource MEMORY_MB:max_unit=10968 --resource MEMORY_MB:total=10968 --amend
done < <(openstack resource provider list -c uuid -c name -f value | head -n 4)
