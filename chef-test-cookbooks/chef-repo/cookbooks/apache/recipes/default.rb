#
# Cookbook Name:: apache
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# Install

package_name = "apache2"
service_name = "apache2"
document_root = "/var/www"

if node["platform"] == "centos"
	package_name = "httpd"
	service_name = "httpd"
	document_root = "/var/www/html"
end

package package_name do
	action :install	
end

# Service
service service_name do
	supports :restart => :true
	action [:enable, :start]
end

#cookbook_file "#{document_root}/index.html" do
#	source "index.html"
#	mode "0644"
#end

template "#{document_root}/index.html" do
	source "index.html.erb"
	mode "0644"
end