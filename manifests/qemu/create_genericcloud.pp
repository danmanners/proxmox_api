# Creates a GenericCloud Image Template
define proxmox_api::qemu::create_genericcloud (
  String[1]   $node,
  String      $vm_name,
  String[1]   $ci_username,
  String[1]   $interface,
  String[1]   $stor,
  Integer     $vmid,
  String      $cloudimage_source,   # URL to download the cloud image from.
  String      $ci_password = '',    # CI Password AND/OR CI Keys must be set. Both should not be empty.
  String      $image_type = '',     # This format type shoule be changed if the cloud image is not qcow2 format.
  String      $ci_keys = '',        # CI Password AND/OR CI Keys must be set. Both should not be empty.
) {

  # Get and parse the facts for VMs, Storage, and Nodes.
  $proxmox_qemu     = parsejson($facts['proxmox_qemu'])

  # Generate a list of VMIDS
  $vmids = $proxmox_qemu.map|$hash|{$hash['vmid']}

  # Validate that the VMID doesn't already exist.
  if $vmid in $vmids {
    # Error out
    fail('VMID already exists!')
  }

  # URI Encodes the SSH Keys
  if $ci_keys != '' {
    $sshkeys = "-sshkeys ${ci_keys}"
  }

  # Check if Cloud-Init Password is Set
  if $ci_password != '' {
    $if_ci_password = "--cipassword='${ci_password}'"
  }

  # Create the directory for the new QEMU VM
  file{"/mnt/${stor}/images/${vmid}":
    ensure => directory,
  }

  # Download the QEMU VM Template Image
  file{"/mnt/${stor}/images/${vmid}/base-${vmid}-disk-0.${image_type}":
    ensure => present,
    source => $cloudimage_source,
    mode   => '0644',
  }

  # If necessary, convert the image format to qcow2.
  if $image_type != '' {
    exec{'convert_image_file':
      command => "/usr/bin/qemu-img convert -f raw -O qcow2 \
        /mnt/${stor}/images/${vmid}/base-${vmid}-disk-0.${image_type} \
        /mnt/${stor}/images/${vmid}/base-${vmid}-disk-0.qcow2",
    }
  }

  # Create the new QEMU VM
  exec{"create_vm_${vmid}":
    command => "/usr/bin/pvesh create /nodes/${node}/qemu \
      --serial0=socket --vga=serial0 \
      --boot=c --agent=1 --bootdisk=scsi0 \
      --ostype=l26 \
      --net0='model=e1000,bridge=${interface}' \
      --numa 0 --template=1 --name='${vm_name}' --vmid=${vmid} \
      --scsi0='${stor}:${vmid}/base-${vmid}-disk-0.qcow2,size=8G' \
      --sockets=1 --cores=1 --memory=2048 -scsihw='virtio-scsi-pci'",
    onlyif  => "/usr/bin/test -f /mnt/${stor}/images/${vmid}/base-${vmid}-disk-0.qcow2"
  }

  # Create the Cloud-Init VM
  exec{"create_cloudinit_${vmid}":
    command => "/usr/sbin/qm set ${vmid} --ide2 local-lvm:cloudinit",
    require => Exec["create_vm_${vmid}"]
  }

  # Set the configuration for the new QEMU Template VM
  exec{"update_cloudinit_${vmid}":
    command => "/usr/bin/pvesh set /nodes/${node}/qemu/${vmid}/config \
      --ciuser='${ci_username}' -ipconfig0='ip=dhcp' ${sshkeys} \
      ${if_ci_password}",
    require => Exec["create_cloudinit_${vmid}"]
  }
}
