# Cookbook Name:: azkaban2
# Recipe:: executor server
#
# Copyright 2013, Yieldbot
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

# == Recipes
include_recipe "java"

user =  node[:azkaban][:executor][:user]
group = node[:azkaban][:executor][:group]

install_dir = node[:azkaban][:install_dir]

version = node[:azkaban][:version]
fqdn = node[:fqdn].dup # use this as the assumed mysql host

ws_dir = "azkaban-executor-#{version}"
tarball = "azkaban-executor-server-#{version}.tar.gz"

node.set[:azkaban][:executor][:download_url] = "https://s3.amazonaws.com/azkaban2/azkaban2/#{version}/#{tarball}"
download_file = node[:azkaban][:executor][:download_url]

jobtype_plugin_tarball = "/azkaban-jobtype-#{version}.tar.gz"
jobtype_plugin_download = "https://s3.amazonaws.com/azkaban2/azkaban-plugins/#{version}/azkaban-jobtype-#{version}.tar.gz"
jobtype_plugin_ext_dir = "#{install_dir}/#{ws_dir}/plugins/azkaban-jobtype-#{version}"

# create installation directory
directory "#{install_dir}" do
  owner user
  group group
  mode 00755
  recursive true
  action :create
end

# download and unpack tar
remote_file "#{Chef::Config[:file_cache_path]}/#{tarball}" do
  source download_file
  mode 00644
end

execute "tar" do
  user  user
  group group
  cwd install_dir
  command "tar zxvf #{Chef::Config[:file_cache_path]}/#{tarball}"
end

# download JDBC connector jar
# NB you'll need to host it internally somewhere
jdbc_jar = "mysql-connector.jar"

remote_file "#{install_dir}/#{ws_dir}/extlib/#{jdbc_jar}" do
  source node[:azkaban][:jdbc_jar_url]
  mode 00644
end

# set up templates
template "#{install_dir}/#{ws_dir}/bin/azkaban-executor-start.sh" do
  source "azkaban-executor-start.sh.erb"
  owner user
  group group
  mode  00755
end

template "#{install_dir}/#{ws_dir}/bin/azkaban-executor-shutdown.sh" do
  source "azkaban-executor-shutdown.sh.erb"
  owner user
  group group
  mode  00755
end

template "#{install_dir}/#{ws_dir}/conf/azkaban.properties" do
  source "azkaban.properties.erb"
  owner user
  group group
  mode  00755
  variables({
      :mysql_host => fqdn
  })
end

template "azkaban-executor-init" do
    path "/etc/init.d/azkaban-executor"
    source "azkaban-executor-init-script.sh.erb"
    owner "root"
    group "root"
    mode "0755"
    notifies :restart, "service[azkaban-executor]"
end

directory "#{install_dir}/#{ws_dir}/logs" do
  owner user
  group group
  mode 00755
  recursive true
  action :create
end

service "azkaban-executor" do
    pattern 'azkaban-executor'
    supports :restart => true, :start => true, :stop => true
    action [ :nothing ]
end

# apparently we need to create this (empty) directory... 
# ...which we'll actually use for, strangely enough, the jobtypes plugin
directory "#{install_dir}/#{ws_dir}/plugins/jobtypes" do
  owner user
  group group
  mode 00755
  recursive true
  action :create
end

if node[:azkaban][:include_jobtype_plugin]
  # download and unpack tar
  remote_file "#{Chef::Config[:file_cache_path]}/#{jobtype_plugin_tarball}" do
    source jobtype_plugin_download
    mode 00644
  end

  execute "tar" do
    user  user
    group group
    cwd "#{install_dir}/#{ws_dir}/plugins"
    command "tar zxvf #{Chef::Config[:file_cache_path]}/#{jobtype_plugin_tarball}"
    not_if { File.exists?('#{node[:azkaban][:install_dir]}/azkaban_misc/.jobtypes_installed') }
  end

  bash 'do_azkaban_jobtypes_init' do
    code <<-EOH
      mv #{jobtype_plugin_ext_dir}/* #{install_dir}/#{ws_dir}/plugins/jobtypes
      rmdir #{jobtype_plugin_ext_dir}
      touch #{node[:azkaban][:install_dir]}/azkaban_misc/.jobtypes_installed
    EOH
    cwd "#{node[:azkaban][:install_dir]}/azkaban_misc"
    user "root"
    not_if { File.exists?('#{node[:azkaban][:install_dir]}/azkaban_misc/.jobtypes_installed') }
    action :run
  end

  template "#{install_dir}/#{ws_dir}/plugins/jobtypes/commonprivate.properties" do
    source "jobtype-commonprivate.properties.erb"
    owner user
    group group
    mode  00755
    # variables({
    #     :mysql_host => fqdn
    # })
  end
end
