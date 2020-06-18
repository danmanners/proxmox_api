# Get the next VM ID for the Proxmox Cluster.
Facter.add('proxmox_cluster_nextid') do
    setcode do
        Facter::Core::Execution::execute('/usr/bin/pvesh get /cluster/nextid')
    end                
end

# pvesh get /cluster/resources -type=vm --output-format json | jq '.[] | {vmid: .vmid, node: .node, info: {name: .name, status: .status, cpu: .maxcpu, mem: .maxmem, disk: .maxdisk }}'
# pvesh get /nodes/pmx/qemu --output-format json | jq  '.[] | select (.vmid) | {vmid: .vmid, name: .name, stats: {cpus: .cpus, mem: .maxmem, disk: .maxdisk, status: .status}}''