#
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

provides :chef_run

property :run_list, :name_property => true
property :cookbook_path
property :included_attrs, :default => []
property :show_run, [TrueClass, FalseClass], :default => true

action :run do
  converge_by "Running chef-run with run list #{new_resource.run_list}" do
    old_config = Chef::Config.save
    old_initialization_options = Chef::Cookbook::FileVendor.initialization_options
    old_vendor_class = Chef::Cookbook::FileVendor.vendor_class
    mutate_chef_config
    converge
    Chef::Config.restore(old_config)
    Chef::Cookbook::FileVendor.instance_variable_set(:@initialization_options, old_initialization_options)
    Chef::Cookbook::FileVendor.instance_variable_set(:@vendor_class, old_vendor_class)
  end
end

action_class do
  def mutate_chef_config
    Chef::Config[:cookbook_path] = new_resource.cookbook_path if new_resource.cookbook_path
    Chef::Config[:cache_type] = 'Memory'
    Chef::Config[:no_lazy_load] = true
    if !new_resource.show_run
      Chef::Config[:force_logger] = true
    end
    Chef::Config[:solo_legacy_mode] = true
  end

  def my_node
    @my_node ||= my_client.build_node
  end

  def my_client
    return @my_client if @my_client
    @my_client = Chef::Client.new
    @my_client.ohai.data = node.automatic.dup
    @my_client.load_node
    @my_client.build_node
    @my_client
  end

  def converge
    my_node.run_list.reset!
    new_resource.run_list.gsub(/\s/, "").split(",").each do |i|
      my_node.run_list.add(i)
    end
    my_client.expanded_run_list
    new_resource.included_attrs.each do |attr_name|
      @my_node.consume_attributes({attr_name => run_context.node[attr_name].to_hash.dup})
    end
    @my_run_context = my_client.setup_run_context
    my_client.converge(@my_run_context)
  end
end
