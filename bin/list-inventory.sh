#!/bin/bash
: '
List inventory
for nevron-compute-01,2,3,4
'
source ~/api/admin-openrc

while read row
do
  uuid=$(echo $row | cut -d ' ' -f 1)
  echo $row
  openstack resource provider inventory list $uuid
done < <(openstack resource provider list -c uuid -c name -f value | head -n 4)
