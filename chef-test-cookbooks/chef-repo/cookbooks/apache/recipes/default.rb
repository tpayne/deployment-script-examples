#
# Cookbook Name:: apache
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# Install
package "apache2" do
	action :install	
end

# Service
service "apache2" do
	supports :restart => :true
	action [:enable, :start]
end

cookbook_file "/var/www/index.html" do
	source "index.html"
	mode "0644"
end