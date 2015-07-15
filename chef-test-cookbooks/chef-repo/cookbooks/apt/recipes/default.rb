#
# Cookbook Name:: apt
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

execute "apt update" do
	command "apt-get update"
end

