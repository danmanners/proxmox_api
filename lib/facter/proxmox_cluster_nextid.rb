# Get the next VM ID for the Proxmox Cluster.
Facter.add('proxmox_cluster_nextid') do
    confine :exists => "/usr/bin/pvesh"
    setcode do
        Facter::Core::Execution.execute('/usr/bin/pvesh get /cluster/nextid')
    end                
end
