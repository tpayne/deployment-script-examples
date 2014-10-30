# == Class: test
#
# Full description of class test here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'test':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2014 Your name here, unless otherwise noted.
#
class test {
  include test::params
  $packnameDir = "${test::params::package_name}_dir" 
  $baseDir = "control"

  file { "$baseDir":
     path => "/tmp/${baseDir}",
     ensure => "directory",
  }

  define create_dirs {
    file { "/tmp/${baseDir}/${title}":
      ensure => "directory",
      recurse => true,
    }
    file { "/tmp/${baseDir}/${title}/package":
      ensure => "directory",
      recurse => true,
    }
  }

  create_dirs { ["test1","test2","test3"]: }

  file { "$packnameDir":
   path => "/tmp/${baseDir}/${packnameDir}",
     ensure => "directory",
  }

  service { "tomcat-stop" :
    provider => "init",
    ensure => stopped,
    start => "${test::params::tomcat_home}/bin/startup.sh",
    stop => "${test::params::tomcat_home}/bin/shutdown.sh",
    status => "",
    restart => "",
    hasstatus => false,
    hasrestart => false,
    before => File["deploy"],
  }

  file { "deploy":
        path => "/tmp/${baseDir}/${packnameDir}/test.war",
        source => "puppet:///modules/test/test.war",
	      require => Service["tomcat-stop"],
  }

  service { "tomcat-start" :
    provider => "init",
    ensure => running,
    start => "${test::params::tomcat_home}/bin/startup.sh",
    stop => "${test::params::tomcat_home}/bin/shutdown.sh",
    status => "",
    restart => "",
    hasstatus => false,
    hasrestart => false,
    require => File["deploy"],
  }

  file {"installFile":
    path => "/tmp/install.sh",
    source => "puppet:///modules/test/install.sh",
    require => Service["tomcat-start"],
  }

  exec {"install_something":
    command => "sh /tmp/install.sh", 
    path => ["/bin","/usr/bin","puppet:///modules/test/"],
    onlyif => "test -f /tmp/install.sh",
    require => File["installFile"],
  } 
	
  $varName = "lala"
  $varNameEx = "lala1"

  file {"subFile":
    path => "/tmp/${baseDir}/varTest.txt",
    content => template("test/varTest.erb")
  }

  #package { "openssl":
  #  ensure => "installed",
  #  provider => "pkgdmg",
  #  source => "puppet:///modules/test/"
  #}
}
