require 'json'

module ClusterResourcesVMs
    def self.add_fact(prefix, key, value)
        key = "#{prefix}_#{key}".to_sym
        ::Facter.add(key) do
            setcode { value }
        end
    end

    def self.run
        begin
            qemu = {}
            # Get the next VM ID for the Proxmox Cluster.
            # MAKE SURE TO CHANGE `[0]` WITH `[]` BEFORE PROD
            key_prefix = "proxmox::qemu"
            # qemu = Facter::Core::Execution::execute('pvesh get /cluster/resources -type=vm --output-format json | jq -c')
            # Get the list of Proxmox resources
            qemu = Facter::Core::Execution::execute("pvesh get /cluster/resources -type=vm --output-format json | jq -c '.[] | {vmid: .vmid, node: .node, name: .name, status: .status, cpu: .maxcpu, mem: .maxmem, disk: .maxdisk }'")
            
            vmids = []

            preparse = split(qemu,'\n')
            preparse.each do |vmid|
                vmids << vmid['vmid']
                vmid.each do |key,value|
                    prefix = "#{key_prefix}_qemu_#{vmid['vmid']}"
                    add_fact(prefix, key, value) unless key == 'vmid'
                end
            end
        end
    end
        # add_fact(key_prefix, 'qemu', vmids.join(','))
        # add_fact(key_prefix, 'vmid',    json_data['vmid']   )
        # add_fact(key_prefix, 'node',    json_data['node']   )
        # add_fact(key_prefix, 'name',    json_data['name']   )
        # add_fact(key_prefix, 'status',  json_data['status'] )
        # add_fact(key_prefix, 'cpu',     json_data['maxcpu'] )
        # add_fact(key_prefix, 'mem',     json_data['maxmem'] )
        # add_fact(key_prefix, 'disk',    json_data['maxdisk'])
end

ClusterResourcesVMs.run
# pvesh get /cluster/resources -type=vm --output-format json | jq '.[] | {vmid: .vmid, node: .node, info: {name: .name, status: .status, cpu: .maxcpu, mem: .maxmem, disk: .maxdisk }}'
# pvesh get /nodes/pmx/qemu --output-format json | jq  '.[] | select (.vmid) | {vmid: .vmid, name: .name, stats: {cpus: .cpus, mem: .maxmem, disk: .maxdisk, status: .status}}''