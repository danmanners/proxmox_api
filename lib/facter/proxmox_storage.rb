# The goal of this file is that it will allow an immediate and dynamic ability to gather facts on all of the existing QEMU VMs
Facter.add('proxmox_storage') do
    setcode do
        if File.exist? "/usr/bin/pvesh"
            Facter::Core::Execution.execute("/usr/bin/pvesh get /cluster/resources -type=storage --output-format json")
        end
    end
end
