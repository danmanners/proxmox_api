# Creates a GenericCloud Image Template
define proxmox_api::qemu::create_genericcloud (
  String[1]         $pmx_node,
  String            $vm_name,
  String[1]         $ci_username,
  String[1]         $interface,
  String[1]         $storage_id,
  Integer           $vmid,
  String            $cloudimage_source,   # URL to download the cloud image from.
  String[1]         $default_disk_size = '8G',
  Boolean           $protected = false,
  Optional[String]  $ci_password = undef,    # CI Password AND/OR CI Keys must be set. Both should not be empty.
  Optional[String]  $image_type = undef,     # This format type shoule be changed if the cloud image is not qcow2 format.
  Optional[String]  $ci_keys = undef,        # CI Password AND/OR CI Keys must be set. Both should not be empty.
) {

  # Get and parse the facts for VMs, Storage, and Nodes.
  $proxmox_qemu = parsejson($facts['proxmox_qemu'])

  # Generate a list of VMIDS
  $vmids = $proxmox_qemu.map|$hash|{$hash['vmid']}

  # Create Image Source Filename
  $image_filename = regsubst($cloudimage_source, ".*/(.*\\b)(.${image_type})",'\\1')

  # Validate that the VMID doesn't already exist, and only create if it doesn't.
  if ! ($vmid in $vmids) {
    # URI Encodes the SSH Keys
    if $ci_keys {
      $sshkeys = "-sshkeys ${ci_keys}"
    } else {
      $sshkeys = ''
    }

    # Check if Cloud-Init Password is Set
    if $ci_password {
      $if_ci_password = "--cipassword='${ci_password}'"
    } else {
      $if_ci_password = ''
    }

    # Check if the VM should be protected
    if $protected  {
      $if_protected = '--protection 1'
    } else {
      $if_protected = ''
    }

    # Sets up storage, volume, and filetype values.
    if ($storage_id == 'local' and $image_type != 'xz') {
      $storage_volume = '/var/lib/vz'
      $volume_name    = 'local'
      $output_type    = $image_type
    } elsif ($storage_id != 'local' and ($image_type !='xz' or $image_type == 'xz')) {
      $storage_volume = "/mnt/${storage_id}"
      $volume_name    = $storage_id
      $output_type    = 'qcow2'
    } elsif ($storage_id == 'local' and $image_type == 'xz') {
      $storage_volume = '/var/lib/vz'
      $volume_name    = 'local'
      $output_type    = 'qcow2'
    }

    # Create the directory for the new QEMU VM
    file{"${storage_volume}/images/${vmid}":
      ensure => directory,
    }

    # Download the QEMU VM Template Image
    if $image_type in ['img','qemu2'] {
      file{"${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${image_type}":
        ensure => present,
        source => $cloudimage_source,
        mode   => '0644',
      }
    # If it's an xz type image file, download 
    } elsif $image_type == 'xz' {
      file{"${storage_volume}/images/${vmid}/${image_filename}.${image_type}":
        ensure => present,
        source => $cloudimage_source,
        mode   => '0644',
      }
    } else {
      fail('Only [qemu,img,xz,tar.gz] filetypes are supported at this time.')
    }

    # If necessary, convert the image format to qcow2 or decompress the file type to the right location.
    if $image_type == 'img' and $volume_name != 'local' {
      exec{'convert_img_file':
        command => "/usr/bin/qemu-img convert -f raw -O ${output_type} \
          ${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${image_type} \
          ${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${output_type} && \
          /usr/bin/rm -f ${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${image_type}",
      }
    } elsif $image_type == 'xz' {
      # Sets up file name
      exec{'unpack_xz_file':
        command => "/usr/bin/unxz \
          ${storage_volume}/images/${vmid}/${image_filename}.${image_type} && \
          /usr/bin/mv ${storage_volume}/images/${vmid}/${image_filename} \
          ${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${output_type}",
      }
    }

    # Create the new QEMU VM
    exec{"create_vm_${vmid}":
      command => "/usr/bin/pvesh create /nodes/${pmx_node}/qemu \
        --serial0=socket --vga=serial0 --boot=c --agent=1 --bootdisk=scsi0 \
        --net0='model=e1000,bridge=${interface}' ${if_protected} \
        --ide2 ${volume_name}:cloudinit --sockets=1 --cores=1 \
        --memory=2048 -scsihw='virtio-scsi-pci' --ostype=l26 \
        --numa 0 --template=1 --name='${vm_name}' --vmid=${vmid}",
    }

    # Set the configuration for the new QEMU Template VM
    exec{"update_cloudinit_${vmid}":
      command => "/usr/bin/pvesh set /nodes/${pmx_node}/qemu/${vmid}/config \
        --ciuser='${ci_username}' ${sshkeys} ${if_ci_password} -ipconfig0='ip=dhcp'",
      require => Exec["create_vm_${vmid}"]
    }

    # If running on Local-LVM, set all of that up.
    if $volume_name == 'local' {
      # Import the Image to local-lvm.
      exec{"import_qm_image_${vmid}":
        command => "/usr/sbin/qm importdisk \
          ${vmid} ${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${output_type} local-lvm",
        require => Exec["create_vm_${vmid}"]
      }

      # Cleanup the Original Image File
      exec{"cleanup_original_image_${vmid}":
        command => "/usr/bin/rm -f \
          ${storage_volume}/images/${vmid}/base-${vmid}-disk-0.${output_type}",
        require => Exec["import_qm_image_${vmid}"]
      }

      # Set the new local-lvm image to iscsi disk0
      exec{"set_qm_image_${vmid}":
        command => "/usr/sbin/qm set \
          ${vmid} --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-${vmid}-disk-0",
        require => Exec["import_qm_image_${vmid}"]
      }

      # Resize the VM to 8GB starting size.
      exec{"update_vm_sizing_${vmid}":
        command => "/usr/bin/pvesh set \
          /nodes/${pmx_node}/qemu/${vmid}/resize -disk=scsi0 --size=${default_disk_size}",
        require => Exec["set_qm_image_${vmid}"]
      }
    }
  }
}
