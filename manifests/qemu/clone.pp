# Clones an existing Proxmox QEMU VM image.
# 
# This definition creates a QEMU Virtual Machine clone baesd on a template.
#
# Paramters:
#   [*pmx_node*]          - The Proxmox node to create the clone on.
#   [*clone_id*]          - The ID of the QEMU template to clone.
#   [*vm_name*]           - The name of the new VM.
#   [*disk_size*]         - OPTIONAL: The size of the new VM disk. If undefined, the size of the VM template disk will be kept.
#   [*disk_target]        - OPTIONAL: The storage location for the new VM disk. If undefined, will default to the Templates volume.
#   [*description*]       - OPTIONAL: The 
#   [*cpu_sockets*]       - The number of CPU sockets to be assigned to the new VM.
#   [*cpu_cores*]         - The number of CPU cores to be assigned to the new VM.
#   [*memory*]            - The amount of memory to be assigned to the new VM, in Megabytes (2GB = 2048).
#   [*protected*]         - OPTIONAL: If true, it will protect the new VM from accidental deletion.
#   [*ipv4_static]        - Boolean. If true, you must define the CIDR and Gateway values.
#   [*ipv4_static_cidr*]  - OPTIONAL: If ipv4_static is true, this value must be in the format '192.168.1.20/24'.
#   [*ipv4_static_gw*]    - OPTIONAL: If ipv4_static is true, this value must be in the format '192.168.1.1'.
#   [*ci_username*]       - OPTIONAL: The default username for the Cloud-Init drive to be configured.
#   [*ci_password*]       - OPTIONAL: The default password for the Cloud-Init drive to be configured.
#   [*newid*]             - OPTIONAL: The ID for the new Virtual Machine. If unassigned, the next available ID will be used.
#   [*clone_type*]        - Boolean. If true, a full disk clone will be created. If false, a linked-clone will be created. Not recommended.
#
define proxmox_api::qemu::clone (
  # Clone Settings
  String[1]         $pmx_node,
  Integer[1]        $clone_id,
  String[1]         $vm_name,
  String            $disk_size,
  Optional[String]  $disk_target  = undef,
  Optional[String]  $description  = undef,
  Integer           $newid         = Integer($facts['proxmox_cluster_nextid']),
  # VM Settings
  Integer           $cpu_sockets  = 1,
  Integer           $cpu_cores    = 1,
  Integer           $memory       = 2048,
  Boolean           $protected    = false,
  Boolean           $clone_type    = true,
  # Network & Cloud-Init Settings
  Optional[Boolean] $ipv4_static  = false,
  Optional[String]  $ipv4_static_cidr = undef, # Needs to be in the format '192.168.1.20/24'
  Optional[String]  $ipv4_static_gw = undef, # Needs to be in the format '192.168.1.1'
  Optional[String]  $ci_username,
  Optional[String]  $ci_password,
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
    if $hash['node'] == $pmx_node {
      $hash['storage']
    }
  }

  # Evaluate variables to make sure we're safe to continue.
  # Confirm that the Clone ID is not the same as the New ID.
  if $clone_id != $newid {
    # If the Clone ID is not in the list of Templates, error out.
    if ! ($clone_id in $templates) {
      fail('clone_id does not appear to exist.')
    }
    # If the Clone ID is the same as the New ID, error out.
  } elsif $clone_id == $newid {
    fail('The clone_id and newid values cannot match.')
  }

  # Confirm that the New ID is not in the list of existing VMIDs.
  # If the New ID is in the list, simply don't attempt to create/overwrite it.
  if ! ($newid in $vmids) {
    # Evaluate if there's a Description string.
    if $description {
      $if_description = "--description='${description}'"
    }

    # Evaluate if there's a Disk Target String.
    if $disk_target {
      if $disk_target in $disk_targets {
        $if_disk_target = "--storage='${disk_target}'"
      } else {
        fail('The disk target cannot be found.')
      }
    } else {
      $if_disk_target = ''
    }

    # Evaluate if the VM should be protected
    if ($protected == true) {
      $if_protection = '--protection 1'
    } else {
      $if_protection = ''
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
    if $ipv4_static == true {
      if (($ipv4_static_cidr =~ Stdlib::IP::Address::V4) == false) and ($ipv4_static_cidr != '') {
        fail('IP address is in the wrong format or undefined.')
      }
      if (($ipv4_static_gw =~ Stdlib::IP::Address::V4) == false) and ($ipv4_static_gw != '') {
        fail('Gateway address is in the wrong format or undefined.')
      }
      # If the above checks pass, set the ip settings
      $if_nondhcp = "--ipconfig0='ip=${ipv4_static_cidr},gw=${ipv4_static_gw}'"
    } else {
      $if_nondhcp = ''
    }

    # Create the VM
    exec{"clone_${clone_id}_to_${newid}":
      command => "/usr/bin/pvesh create /nodes/${pmx_node}/qemu/${clone_id}/clone --newid=${newid} \
      --name=${vm_name} ${if_description} ${if_disk_target} ${if_clone_type}",
    }

    # Set the disk size
    if $disk_size {
      exec{"set_disk_size_${newid}":
        command => "/usr/bin/pvesh set /nodes/${pmx_node}/qemu/${newid}/resize \
        -disk=scsi0 --size=${disk_size}",
        require => Exec["clone_${clone_id}_to_${newid}"],
      }
    }

    # Set the Cloud-Init Values
    exec{"set_qemu_values_${newid}":
      command => "/usr/bin/pvesh set /nodes/${pmx_node}/qemu/${newid}/config \
      --sockets=${cpu_sockets} --cores=${cpu_cores} --memory=${memory} \
      ${if_protection} ${if_ciuser} ${if_cipassword} ${if_nondhcp}",
      require => Exec["set_disk_size_${newid}"],
    }
  }
}
