
def initialize(*args)
  super
  @resource_name = :github
  @action = :upload
end

action :setup do
  #@todo find another way to wait for running zookeeper before installing solr cloud
  sleep 120

  set_zookeeper_hosts

  run_context.include_recipe "opsworks_solrcloud::solrcloud_install"
end

action :deployconfig do
  set_zookeeper_hosts

  Chef::Log.info("Starting deployment of solr configuration")
  Chef::Log.info("Using jetty context #{node['solrcloud']['jetty_config']['context']['path']}")
  Chef::Log.info("Using solr core admin path #{node['solrcloud']['solr_config']['admin_path']}")

  run_context.include_recipe "opsworks_solrcloud::solrcloud_deployconfig"
end

action :getconfig do
  run_context.include_recipe 'aws'
  Chef::Log.info("Getting solr configuration from s3 bucket")

  zkconfigtar_tmp = "/tmp/zkconfigtar/"

  directory zkconfigtar_tmp do
    recursive true
    action :delete
  end

  directory zkconfigtar_tmp do
    owner 'root'
    group 'root'
    mode '0644'
    action :create
  end

  aws_s3_file "#{zkconfigtar_tmp}solrconfig.tar.gz" do
    bucket new_resource.zkconfigsets_s3_bucket
    remote_path new_resource.zkconfigsets_s3_remote_path
    aws_access_key_id new_resource.zkconfigsets_s3_aws_access_key_id
    aws_secret_access_key new_resource.zkconfigsets_s3_aws_secret_access_key
  end

  bash "zkconfigtar" do
    cwd zkconfigtar_tmp
    code <<-EOF
         tar xvfz solrconfig.tar.gz
         rm solrconfig.tar.gz
         cp -R * #{node['solrcloud']['zkconfigsets_home']}
    EOF
  end
end

action :restart do
  service "solr" do
    action :restart
  end
end

private
def setzkhosts
  firsthost = node['opsworks']['layers']['solrcloud']['instances'].first[1]

  exhibitor_url = "http://#{firsthost['private_dns_name']}:8080/"
  Chef::Log.info("Exhibitor node is #{exhibitor_url}")

  hostarray = discover_zookeepers(exhibitor_url)
  if hostarray.nil?
    Chef::Application.fatal!('Failed to discover zookeepers. Cannot continue')
  end

  port = hostarray['port']
  servers = hostarray['servers']
  servers_and_ports = []

  servers.each do |server|
    servers_and_ports.push("#{server}:#{port}")
  end

  Chef::Log.info("Using zookeeper hosts string for solr #{servers_and_ports}")
  node.override['solrcloud']['solr_config']['solrcloud']['zk_host'] = servers_and_ports
end