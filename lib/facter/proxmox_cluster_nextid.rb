# Get the next VM ID for the Proxmox Cluster.
Facter.add('proxmox_cluster_nextid') do
    setcode do
        if File.exist? "/usr/bin/pvesh"
            Facter::Core::Execution.execute('/usr/bin/pvesh get /cluster/nextid')
        end
    end
end
