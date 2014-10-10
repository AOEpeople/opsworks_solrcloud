action :setup do

    #
    # Use version 7 of java
    #
    node.set['java']['jdk_version'] = '7'

    #
    # Manage zookeeper control with exhibitor
    #
    node.set['zookeeper']['service_style'] =  'exhibitor'

    #
    # Configure exibitor to use all cluster nodes a zookeeper instance nodes
    #
    servers = []
    instances = node['opsworks']['layers']['solrcloud']['instances']
    instances.each_with_index do |instance, index|
        private_ip = instance[1]['private_ip']
        hostindex = index + 1
        servers.push("#{hostindex}:#{private_ip}")
    end

    server_specs = servers.join(",");

    Chef::Log.info("Using #{server_specs} as exhibitor server_specs")

    node.set['exhibitor']['config'] = {
      cleanup_period_ms: 5 * 60 * 1000,
      check_ms: '30000',
      backup_period_ms: '0',
      client_port: '2181',
      cleanup_max_files: '20',
      backup_max_store_ms: '0',
      connect_port: '2888',
      backup_extra: '',
      observer_threshold: '0',
      election_port: '3888',
      zoo_cfg_extra: 'tickTime\=2000&initLimit\=10&syncLimit\=5',
      auto_manage_instances_settling_period_ms: '0',
      auto_manage_instances: '1',
      servers_spec: "#{server_specs}"
    }

    run_context.include_recipe 'exhibitor::default'
    run_context.include_recipe 'runit'
    run_context.include_recipe 'zookeeper::service'

    directory "/var/lib/zookeeper" do
      group 'zookeeper'
      owner 'zookeeper'
      mode 0775
      recursive true
    end

    run_context.include_recipe 'exhibitor::service'
end