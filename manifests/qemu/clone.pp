# Clones an existing Proxmox QEMU VM image.
# Sets all of the relevant settings through several commands.
define proxmox_api::qemu::clone (
  # Clone Settings
  String[1]         $node,
  Integer[1]        $clone_id,
  String[1]         $vm_name,
  Integer           $newid            = Integer($facts['proxmox_cluster_nextid']),
  Boolean           $clone_type       = true,
  Optional[String]  $description      = Undef,
  Optional[String]  $disk_target      = Undef,
  # VM Settings
  Integer     $disk_size              = 8, # Make sure you only use whole numbers larger than 8; this is multiplied by 1024.
  Integer     $cpu_sockets            = 1,
  Integer     $cpu_cores              = 1,
  Integer     $memory                 = 2048,
  Boolean     $protected              = false,
  # Cloud-Init Values
  Optional[Boolean] $ipv4_static      = false,
  Optional[String]  $ipv4_static_cidr = Undef, # Needs to be in the format '192.168.1.20/24'
  Optional[String]  $ipv4_static_gw   = Undef, # Needs to be in the format '192.168.1.1'
  Optional[String]  $ci_username      = Undef,
  Optional[String]  $ci_password      = Undef,
  # String      $ci_sshkey        = '', # Commented out; difficulties below.
) {

  # Get and parse the facts for VMs, Storage, and Nodes.
  $proxmox_qemu     = parsejson($facts['proxmox_qemu'])
  $proxmox_storage  = parsejson($facts['proxmox_storage'])
  $proxmox_nodes    = parsejson($facts['proxmox_nodes'])

  # Generate a list of VMIDS
  $vmids = $proxmox_qemu.map|$hash|{$hash['vmid']}
  # Generate a list of all Proxmox Nodes
  $nodes = $proxmox_qemu.map|$hash|{$hash['node']}
  # Generate a list of all Proxmox QEMU Templates
  $templates = $proxmox_qemu.map|$hash|{
    if $hash['template'] == 1 {
      $hash['vmid']
    }
  }
  # Generate a list of all storage mediums on the specified node
  $disk_targets = $proxmox_storage.map|$hash|{
    if $hash['node'] == $node {
      $hash['storage']
    }
  }

  # Evaluate variables to make sure we're safe to continue.
  if $clone_id != $newid {
    if $newid in $vmids {
      # Error out
      fail('clone_id already exists!')
    }
    if ! ($clone_id in $templates) {
      # Error out
      fail('clone_id does not appear to exist.')
    }
  } elsif $clone_id == $newid {
    # Error Out
    fail('The clone_id and newid values cannot match.')
  }

  # Evaluate if there's a Description string.
  if $description != '' {
    $if_description = "--description='${description}'"
  }

  # Evaluate if there's a Disk Target String.
  if $disk_target != '' {
    if $disk_target in $disk_targets {
      $if_disk_target = "--target='${disk_target}'"
    } else {
      fail('The disk target cannot be found.')
    }
  }

  # Evaluate if the VM should be protected
  if ($protected == true) {
    $if_protection = '--protection 1'
  }

  # Evaluate if there's a Clone Type Boolean
  if ($clone_type == true) {
    $if_clone_type = '--full 1'
  }

  # Check if there's a custom Cloud-Init User
  if ($ci_username != '') {
    $if_ciuser = "--ciuser=${ci_username}"
  }

  # Check if there's a custom Cloud-Init Password
  if ($ci_password != '') {
    $if_cipassword = "--cipassword='${ci_username}'"
  }

  # Check if there's a custom Cloud-Init SSH Key, and URI encodes it
  # Commented out, having immense difficulty figuring out the correct string format.
  # if ($ci_sshkey != '') {
  #   $uriencodedsshkey = uriescape($ci_sshkey)
  #   $if_cisshkey = "--sshkeys=${uriencodedsshkey}"
  # }

  # Check if there are custom Cloud-Init network requirements
  if ($ipv4_static == true) {
    if (($ipv4_static_cidr =~ Stdlib::IP::Address::V4) == false) and ($ipv4_static_cidr != '') {
      fail('IP address is in the wrong format or undefined.')
    }
    if (($ipv4_static_gw =~ Stdlib::IP::Address::V4) == false) and ($ipv4_static_gw != '') {
      fail('Gateway address is in the wrong format or undefined.')
    }
    # If the above checks pass, set the ip settings
    $if_nondhcp = "--ipconfig0='ip=${ipv4_static_cidr},gw=${ipv4_static_gw}'"
  }

  # Create the VM
  exec{"clone_${clone_id}_to_${newid}":
    command => "/usr/bin/pvesh create /nodes/${$node}/qemu/${clone_id}/clone --newid=${newid} \
    --name=${vm_name} ${if_description} ${if_disk_target} ${if_clone_type}",
  }

  # Set the disk size
  $final_disk_size = $disk_size * 1024
  exec{"set_disk_size_${newid}":
    command => "/usr/bin/pvesh set /nodes/${node}/qemu/${newid}/resize \
    -disk=scsi0 --size=${final_disk_size}M",
    require => Exec["clone_${clone_id}_to_${newid}"],
  }

  # Set the Cloud-Init Values
  exec{"set_qemu_values_${newid}":
    command => "/usr/bin/pvesh set /nodes/${node}/qemu/${newid}/config \
    --sockets=${cpu_sockets} --cores=${cpu_cores} --memory=${memory} ${if_protection} \
    ${if_ciuser} ${if_cipassword} ${if_nondhcp}",
    require => Exec["set_disk_size_${newid}"],
  }
}
