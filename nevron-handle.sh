#!/bin/bash

# Wakeonlan
declare -A macs
macs[nevron-controller-01]=B8:AC:6F:3C:C5:12
macs[nevron-controller-02]=B8:AC:6F:3C:B0:54
macs[nevron-compute-01]=BC:EE:7B:DD:60:B6
macs[nevron-compute-02]=BC:EE:7B:DD:61:03
macs[nevron-compute-03]=BC:EE:7B:DD:60:B2
macs[nevron-compute-04]=BC:EE:7B:DD:60:CC
macs[nevron-storage-01]=C8:60:00:CC:84:0E

# Tools
readarray -t TOOLBOX <<EOF
wake_and_wait
unshelve_vms
start_vms
tf_plan_dev
tf_plan_prod
tf_apply_dev
tf_apply_prod
tf_destroy_dev
tf_destroy_prod
run_tasks_on_vms
stop_vms
snapshot_vms
shelve_vms
shutdown_hypervisors
EOF

# Print help if -h or no arguments
if [[ $# -eq 0 ]] || [[ " $* " == *" -h "* ]]; then
  cat <<EOF
Usage: $0 [options] [vms] [hypervisors] [pipeline]

Options:
  -h    Show this help message

The rest are three strings containing space separated words with strong ('') or weak ("") quoting

VMs: Virtual Machine names

Hypervisors: Hypervisor hostnames. If empty ('' or ""), will be inferred from VMs

Pipeline: String of tools to run in specified sequantial order

Examples:
nevron-handle 'desktop home-assistant' 'nevron-compute-02' 'stop_vms snapshot_vms start_vms'

Available tools:

$(printf "%s\n" "${TOOLBOX[@]}")
EOF
  exit 0
fi

# Parse arguments
VM_NAMES=($1)
HYPERVISOR_HOSTNAMES=($2)
PIPELINE=($3)

# Most tools use non-admin openstack user
source api/ivar-openrc

get_hypervisor_hostnames() {
  # TODO Policy to authorize ivar to do this
  # so we don't need admin
  declare -A HOSTNAMES
  for VM in "${VM_NAMES[@]}"; do
    local ID=$(openstack server show "$VM" -f value -c id)
    source api/admin-openrc
    local NAME=$(openstack server show $ID -f value -c OS-EXT-SRV-ATTR:host)
    source api/ivar-openrc
    # If None is returned, VM was not found
    # to be connected to a hypervisor..
    # -> VM is likely SHELVED_OFFLOADED
    [[ "$NAME" == "None" ]] || HOSTNAMES[$NAME]=0
  done

  HYPERVISOR_HOSTNAMES=("${!HOSTNAMES[@]}")
}

# Infer hostnames from VM names
if [ ${#HYPERVISOR_HOSTNAMES[@]} -ne 1 ] && [[ "${HYPERVISOR_HOSTNAMES[0]}" == "" ]]; then
  echo "[hypervisors] is empty, inferring hostnames from [vms]"
  get_hypervisor_hostnames
fi

wake() { wakeonlan -i 10.0.0.255 ${macs[$1]}; }

wake_and_wait() {
  for NAME in "${HYPERVISOR_HOSTNAMES[@]}"; do
    echo "Waking up $NAME..."
    wake "$NAME"

    echo "Waiting for $NAME to become reachable..."
    until ping -c1 "$NAME" &>/dev/null; do
      sleep 5
    done

    echo "$NAME is online."
  done
}

wait_for_vm_state() {
  local VM="$1" STATE="$2"

  echo "Waiting for VM $VM vm_state to become $STATE..."

  until [ "$(openstack server show "$VM" -f value -c OS-EXT-STS:vm_state)" == "$STATE" ]; do
    sleep 5
  done
}

unshelve_vms() {
  echo "Unshelving selected VMs..."
  for VM in "${VM_NAMES[@]}"; do
    status=$(openstack server show "$VM" -f value -c status)
    if [[ "$status" =~ ^SHELVED ]]; then
      echo "Unshelving $VM"
      openstack server unshelve "$VM"
      wait_for_vm_state "$VM" "active"
    else
      echo "Skipping $VM — status is $status"
    fi
  done
}

start_vms() {
  for VM in "${VM_NAMES[@]}"; do
    echo "Starting existing VM: $VM"
    openstack server start "$VM" || echo "VM $VM may already be started."
  done

  for VM in "${VM_NAMES[@]}"; do
    echo "Waiting for VM $VM to become ACTIVE..."
    until [ "$(openstack server show "$VM" -f value -c status)" == "ACTIVE" ]; do
      sleep 5
    done
  done

  echo "All VMs are up."
}

tf_plan_dev() {
  cd ~/Projects/nevron-handle/tf/envs/dev && terraform plan
}

tf_plan_prod() {
  cd ~/Projects/nevron-handle/tf/envs/prod && terraform plan
}

tf_apply_dev() {
  cd ~/Projects/nevron-handle/tf/envs/dev && terraform apply
}

tf_apply_prod() {
  cd ~/Projects/nevron-handle/tf/envs/prod && terraform apply
}

tf_destroy_dev() {
  cd ~/Projects/nevron-handle/tf/envs/dev && terraform destroy
}
tf_destroy_prod() {
  cd ~/Projects/nevron-handle/tf/envs/prod && terraform destroy
}

wait_for_web_service() {
  # Note! HTTP/2 version

  local url="$1"
  local max_attempts=30
  local delay=5

  echo "Waiting for web service at $url..."

  for ((i=1; i<=max_attempts; i++)); do
    if curl -sk --head --connect-timeout 3 $url | grep -qE 'HTTP/2 200|HTTP/2 302'; then
      echo "Web service is up at $url"
      return 0
    else
      echo "[$i/$max_attempts] Not ready yet: $url"
      sleep "$delay"
    fi
  done

  echo "ERROR: Timed out waiting for $url to become available."
  return 1
}

run_tasks_on_vms() {
  # TODO
  TASK_SCRIPT="/opt/vm-automation/remote-task.sh"

  for VM in "${VM_NAMES[@]}"; do
    echo "Retrieving IP for $VM..."
    IP=$(openstack server show "$VM" -f json -c addresses | jq '.addresses.provider[-1]' | tr -d '"')
    if [[ -z "$IP" ]]; then
      echo "Running secondary method for finding IP, not implemented"
    fi

    if [[ -z "$IP" ]]; then
      echo "Could not find IP address for $VM"
      continue
    fi

    # ✅ Wait for web service to be ready
    wait_for_web_service "https://$IP/login/"

    # TODO
    #echo "Uploading task script to $VM ($IP)..."
    #scp -o StrictHostKeyChecking=no -o ConnectTimeout=5 \"$TASK_SCRIPT\" ubuntu@$IP:/tmp/task.sh

    #echo "Running task script on $VM..."
    #ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$IP 'chmod +x /tmp/task.sh && sudo /tmp/task.sh'
  done
}

stop_vms() {
  for VM in "${VM_NAMES[@]}"; do
    echo "Shutting down $VM..."
    openstack server stop "$VM"

    echo "Waiting for VM $VM to enter SHUTOFF state..."
    until [ "$(openstack server show $VM -f value -c status)" == "SHUTOFF" ]; do
      sleep 5
    done

  done
}

snapshot_vm_and_wait() {
  local vm_name="$1"
  local snapshot_name="${vm_name}-snapshot-$(date +%F-%H%M)"

  echo "Creating snapshot for VM $vm_name as $snapshot_name..."

  # Create snapshot, capture image ID
  image_id=$(openstack server image create --name "$snapshot_name" "$vm_name" -f value -c id)
  if [[ -z "$image_id" ]]; then
    echo "Failed to create snapshot image for $vm_name"
    return 1
  fi

  echo "Waiting for snapshot image $image_id to become active..."

  local max_attempts=60
  local delay=10

  for ((i=1; i<=max_attempts; i++)); do
    status=$(openstack image show "$image_id" -f value -c status)
    if [[ "$status" == "active" ]]; then
      echo "Snapshot $snapshot_name for VM $vm_name is complete."
      return 0
    elif [[ "$status" == "error" ]]; then
      echo "Snapshot $snapshot_name failed with error status."
      return 1
    else
      echo "[$i/$max_attempts] Snapshot status: $status. Waiting..."
      sleep "$delay"
    fi
  done

  echo "Timeout waiting for snapshot $snapshot_name to complete."
  return 1
}

snapshot_vms() {
  for VM in "${VM_NAMES[@]}"; do
    snapshot_vm_and_wait "$VM" || echo "Snapshot failed for $VM"
  done
}

wait_for_poweroff() {
  local hostname="$1"
  local max_attempts=30
  local delay=10
  local success_count=0
  local required_successes=2  # Require 2 consistent failures

  echo "Waiting for $hostname to fully power off..."

  for ((i=1; i<=max_attempts; i++)); do
    if ping -c1 -W1 "$hostname" &>/dev/null; then
      echo "[$i/$max_attempts] Still responding to ping..."
      success_count=0  # Reset success counter if it pings back
    else
      ((success_count++))
      echo "[$i/$max_attempts] Ping failed ($success_count/$required_successes)"
      if ((success_count >= required_successes)); then
        echo "$hostname appears to be powered off."
        return 0
      fi
    fi
    sleep "$delay"
  done

  echo "WARNING: Timeout waiting for $hostname to shut down"
  return 1
}

shelve_vms() {
  echo "Shelving selected VMs..."
  for VM in "${VM_NAMES[@]}"; do
    status=$(openstack server show "$VM" -f value -c status)
    if [[ "$status" == "SHUTOFF" ]] || [[ "$status" == "ACTIVE" ]]; then
      echo "Shelving $VM"
      openstack server shelve "$VM"
      wait_for_vm_state "$VM" "shelved_offloaded"
    else
      echo "Skipping $VM — status is $status"
    fi
  done
}

hypervisor_safe_to_shutdown() {
  local hypervisor_name="$1"

  # List VMs on this hypervisor with their statuses
  local running_vms
  # TODO: Policy change so ivar can do this
  # instead of admin
  source api/admin-openrc
  running_vms=$(openstack server list --all-projects --host "$hypervisor_name" -f value -c Name -c Status | grep -v SHUTOFF)
  source api/ivar-openrc

  if [[ -n "$running_vms" ]]; then
    echo "⚠️  Hypervisor $hypervisor_name still has active VMs:"
    echo "$running_vms" | awk '{print " - "$0}'
    return 1  # Not safe
  else
    echo "✅ Hypervisor $hypervisor_name has no running VMs."
    return 0  # Safe
  fi
}

shutdown_hypervisors() {
  for NAME in "${HYPERVISOR_HOSTNAMES[@]}"; do
    if hypervisor_safe_to_shutdown "$NAME"; then
      echo "Stopping OpenStack and libvirt services on hypervisor $NAME..."

      ssh "$NAME" "set -e; sudo systemctl stop nova-compute; sudo systemctl stop neutron-openvswitch-agent; sudo systemctl stop libvirtd"

      echo "Services stopped on $NAME. Now shutting down hypervisor..."
      ssh "$NAME" "sudo systemctl poweroff" || echo "Failed to issue poweroff to $NAME (already down?)"

      wait_for_poweroff "$NAME"
    else
      echo "Skipping shutdown of $NAME – it still has active VMs."
    fi

  done
}

find_tool() {
  local needle=$1
  shift
  for t in "$@"; do
    [[ "$t" == "$needle" ]] && { echo "$t"; return 0; }
  done
  return 1
}

main() {
  for T in "${PIPELINE[@]}"; do
    if TOOL=$(find_tool "$T" "${TOOLBOX[@]}"); then
      $TOOL
    fi
  done
}

main
