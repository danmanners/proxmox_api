# Changelog

## Release 0.1.3

**Features**

- Improving code quality.
- Further ensuring that error handling is best approached.

## Release 0.1.2

**Features**

- Ensured that both `proxmox_api::qemu::create_genericcloud` and `proxmox_api::qemu::clone` are idempotent.
  - If you now re-run either of them with new VMID values targeting ID's that already exist, they will simply not attempt to overwrite what's already there. This allows the same code to be re-run.

**Bugfixes**

- Fixed and reworked the Clone functionality.

## Release 0.1.1

**Update**

- Added the changelog properly
- Updated the `metadata.json` file to add requirements.

## Release 0.1.0 - Initial Commit

**Features**

- Added the capability to "install" Generic Cloud images onto Proxmox.
- Added the capability to provision new images based on existing VMs.

**Bugfixes**

- n/a

