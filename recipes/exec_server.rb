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

exec_dir = "azkaban-exec-server-#{version}"
tarball = "azkaban-exec-server-#{version}.tar.gz"

download_file = node[:azkaban][:executor][:download_url]

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
  not_if { ::File.exists?("#{install_dir}/#{exec_dir}") }
end

['logs', 'conf', 'extlib'].each do |dir|
  directory "#{install_dir}/#{exec_dir}/#{dir}" do
    owner user
    group group
    mode 00755
    recursive true
    action :create
  end
end

# download JDBC connector jar
# NB you'll need to host it internally somewhere
jdbc_jar = "mysql-connector.jar"

remote_file "#{install_dir}/#{exec_dir}/extlib/#{jdbc_jar}" do
  source node[:azkaban][:jdbc_jar_url]
  mode 00644
end

# set up start and init scripts
template "#{install_dir}/#{exec_dir}/bin/azkaban-executor-start.sh" do
  source "azkaban-executor-start.sh.erb"
  owner user
  group group
  mode  00755
  variables({'ak_dir' => "#{install_dir}/#{exec_dir}"})
end

template "#{install_dir}/#{exec_dir}/bin/azkaban-executor-shutdown.sh" do
  source "azkaban-executor-shutdown.sh.erb"
  owner user
  group group
  mode  00755
  variables({'ak_dir' => "#{install_dir}/#{exec_dir}"})
end

template "#{install_dir}/#{exec_dir}/conf/azkaban.properties" do
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
    variables({'ak_dir' => "#{install_dir}/#{exec_dir}"})
end

service "azkaban-executor" do
    pattern 'azkaban-executor'
    supports :restart => true, :start => true, :stop => true
    action [ :nothing ]
end
