Chef::Log.info("Running opsworks solrcloud configure")

include_recipe 'exhibitor::default'

include_recipe 'runit'
include_recipe 'zookeeper::service'
include_recipe 'exhibitor::service'

opsworks_solrcloud "solr cloud" do
  exhibitor_uri "http://#{node['opsworks']['layers']['solrcloud']['instances'][0]['public_dns_name']}:8080/"
end
