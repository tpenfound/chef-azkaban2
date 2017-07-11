# Cookbook Name:: azkaban3
# Recipe:: database setup
#
# Copyright 2017, Tal Penfound
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

install_dir = node[:azkaban][:install_dir]

#mysql setup
mysql_service node['mysql']['service_name'] do
  version node['mysql']['version']
  port node['mysql']['port']
  data_dir node['mysql']['data_dir']
  initial_root_password node['mysql']['initial_root_password']
  action [:create, :start]
end

mysql_client 'default' do
  action :create
end

directory "#{node[:azkaban][:install_dir]}/azkaban_misc" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

template 'azkaban_db_init' do
    path "#{node[:azkaban][:install_dir]}/azkaban_misc/azkaban_db_init.sql"
    source "azkaban_db_init.sql.erb"
    source
    owner "root"
    group "root"
    mode "0755"
    variables('ak_dbname' => node[:azkaban][:mysql][:database],
              'ak_dbuser' => node[:azkaban][:mysql][:user],
              'ak_dbpass' => node[:azkaban][:mysql][:password])
    end

remote_file "#{node[:azkaban][:install_dir]}/azkaban_misc/azkaban-db.tar.gz" do
  source node[:azkaban][:db_init_sql][:download_url]
  mode 00644
  action :create_if_missing
end

bash 'do_azkaban_db_init' do
  code <<-EOH
    mysql -h 127.0.0.1 -u root --password=#{node['mysql']['initial_root_password']} < #{node[:azkaban][:install_dir]}/azkaban_misc/azkaban_db_init.sql
    tar -zxvf azkaban-db.tar.gz
    mysql -h 127.0.0.1 -u root --password=#{node['mysql']['initial_root_password']} --database=#{node[:azkaban][:mysql][:database]} < #{node[:azkaban][:install_dir]}/azkaban_misc/azkaban-db-0.1.0-SNAPSHOT/create-all-sql-0.1.0-SNAPSHOT.sql

    touch .db_inited
  EOH
  cwd "#{node[:azkaban][:install_dir]}/azkaban_misc"
  user "root"
  not_if { File.exists?('#{node[:azkaban][:install_dir]}/azkaban_misc/.db_inited') }
  action :run
end
