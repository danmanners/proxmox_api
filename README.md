# proxmox_api

This `proxmox_api` module allows you to simply and programatically control the [Proxmox Hypervisor](https://proxmox.com/en/).

## Table of Contents

1. [Description](#description)
2. [Setup requirements](#setup-requirements)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)

## Description

This `proxmox_api` module allows you to perform several functions. Currently, this includes:

1. Create GenericCloud Cloud-Init enabled image by simply providing some values.
1. Clone an existing template VM.

## Usage

Examples for each of the commands are below:

### Create new GenericCloud VM Template

```ruby
    proxmox_api::qemu::create_genericcloud {'Ubuntu2004-Template':
      pmx_node          => 'pmx',
          # Proxmox Node to create the VM on
      vm_name           => 'Ubuntu2004-Template',
          # New VM Template Name
      ci_username       => 'ubuntu',
          # Set the Cloud-Init Username
      interface         => 'vmbr0',
          # Set the Proxmox Network adapter to connect the template to
      storage_id        => 'local',
          # Set the storage volume for the VM Template
      default_disk_size => '20G',
          # Defaults to an 8G size if left undefined, but can be set.
      vmid              =>  20001,
          # Set the ID for the new VM Template
      cloudimage_source => 'https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img',
          # URL of the GenericCloud image
      image_type        => 'img',
          # File type of the URL below
    }
```

### Cloning an existing VM Template

```ruby
    proxmox_api::qemu::clone {'test':
      node             => 'pmx',
          # Proxmox Node to create the VM on
      vm_name          => 'TesterMcTesterson',
          # New VM Name
      clone_id         => 1001,
          # The ID of the VM template
      disk_size        => 20,
          # Size of the new disk in GB
      cpu_cores        => 2,
          # Number of CPU cores
      memory           => 4096,
          # Amount of RAM in MB
      ci_username      => 'root',
          # Set the Cloud-Init Username
      ci_password      => 'password',
          # Set the Cloud-Init Password
      protected        => true,
          # Enable the 'Protected' flag
      ipv4_static      => true,
          # [OPTIONAL] Use Static IP
      ipv4_static_cidr => '192.168.1.20/24',
          # [OPTIONAL] Static IP and Subnet Mask
      ipv4_static_gw   => '192.168.1.1',
          # [OPTIONAL] Gateway Address
    }
```

## Recommendations

I'd like to suggest using one of the following URLs for your Generic Cloud Images.

- CentOS 8.2:
  - [CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2](https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2)
- CentOS 7:
  - [CentOS-7-x86_64-GenericCloud](https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-2003.qcow2.xz)
- Ubuntu 20.04:
  - [focal-server-cloudimg-amd64-disk-kvm.img](https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-disk-kvm.img)
- Ubuntu 18.04:
  - [bionic-server-cloudimg-amd64.img](https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img)

## Limitations

- This is currently being developed and tested against a single [Proxmox 6.2-4](https://pve.proxmox.com/wiki/Roadmap#Proxmox_VE_6.2) node, and is not being actively tested against earlier versions. I cannot promise that things will work as expected if you are running earlier versions of Proxmox.
- This will not (but absolutely could) non-template virtual machines. Reason being is that if you're cloning non-template VM's you're probably approaching your infrastructure wrong.

## Development

If there are features that this does not perform or if there are bugs you are encountering, [please feel free to open an issue](https://github.com/danmanners/proxmox_api/issues).

# Known Issues

- Currently, adding SSH keys doesn't work and should be done manually. Looks to be an issue with how Ruby processes urlencoded strings, but otherwise TBD.
