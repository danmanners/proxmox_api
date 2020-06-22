# The goal of this file is that it will allow an immediate and dynamic ability to gather facts on all of the existing QEMU VMs
Facter.add('proxmox_qemu') do
    setcode do
        Facter::Core::Execution.execute("/usr/bin/pvesh get /cluster/resources -type=vm --output-format json")
    end
end
