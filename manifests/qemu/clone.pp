# Clones an existing Proxmox QEMU VM image.
# Sets all of the relevant settings through several commands.
define proxmox_api::qemu::clone (
  # Clone Settings
  String[1]   $node,
  Integer     $clone_id,
  Integer     $newid,
  String      $description      = '',
  Boolean     $clone_type       = true,
  String      $disk_target      = '',
  # VM Settings
  Integer     $disk_size        = 20,
  Integer     $cpu_socket       = 1,
  Integer     $cpu_cores        = 1,
  Integer     $memory           = 2048,
  # Cloud-Init Values
  Boolean     $ipv4_static      = true,
  String[1]   $ipv4_static_cidr = '192.168.1.20/24',
  String[1]   $ipv4_static_gw   = '192.168.1.1',
  String      $ci_ssh_pub_key   = '',
  String      $ci_username      = '',
  String      $ci_password      = '',
) {

  # Evaluate if a VM ID has been defined. Otherwise
  if $newid == 0 {
    $nextid = $facts['proxmox_cluster_nextid']
  } else {
    $nextid = $newid
  }

  $pmx_cluster = $facts['proxmox']

  notify{'title':
    message => $pmx_cluster
  }
}
