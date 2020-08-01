# The goal of this file is that it will allow an immediate and dynamic ability to gather facts on all of the existing QEMU VMs
Facter.add('proxmox_nodes') do
    setcode do
        if File.exist? "/usr/bin/pvesh"
            Facter::Core::Execution.execute("/usr/bin/pvesh get /nodes --output-format json")
        end
    end
end
