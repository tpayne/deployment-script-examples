# == Class: anime
#
# Full description of class anime here.
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
#  class { 'anime':
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

class anime::refresh {
    notify {"This is a refresh of a resource...":}
    # Fire off a refresh...
    file { "animeJpg":
        path => "/tmp/anime.jpg.test",
        source => "puppet:///modules/anime/anime.jpg", 
    }

    exec { 'runUpdate':
        command => '/bin/test 1=1',
        subscribe => File["animeJpg"],
        refreshonly => true,
    }

    file { "animeJpgTest":
        path => "/tmp/anime.jpg",
        source => "/tmp/anime.jpg.test", 
        require => Exec['runUpdate'],
    }
}

class anime::runCmd {
    notify {"This is a command run based of a resource update...":}
    exec { 'doSomeCommand':
      path        => '/usr/local/bin:/usr/bin:/bin',
      command     => 'test 1=1',
      creates    => '/tmp/finished',
      #onlyif     => 'checkstatus.sh',
      #unless     => 'checkstatus.sh',
      refreshonly => true,
      subscribe   => File['animeJpgTest'],
    }

    file { '/tmp/testFile.txt':
        owner   => 'root',
        mode    => '0644',
        content => 'hello world',
    }

}

class anime::testCondition {
    # This is intended to show some test conditions...
    if ($osfamily == 'Darwin') {
        warning('This is a Mac and so does not work')
    } else {
        warning('This is NOT a Mac so will work')
    }

    case $operatingsystem {
        'Darwin': { require anime::thisIsAMac }
        default:  { require anime::thisIsSomethingElse }
    }

    unless $operatingsystem != 'Darwin' {
        notice('This is an UNLESS test')
    }

    $contents = $::operatingsystem ? {
        'centos' => 'Best OS in the world',
        'debian' => 'fail',
        'Darwin' => 'Godlike',
        default  => 'A default OS',
    }

    file { '/tmp/osTest':
        ensure  => file,
        content => $contents
    }
}

class anime::scoping::vars {
    $myVar = "Test"
}

class anime::scoping {
    include anime::scoping::vars
    notice("This is a variable ${anime::scoping::vars::myVar}")
}

class anime::thisIsAMac {
    warning("This is a Mac - really...")
}

class anime::thisIsSomethingElse {
    warning("This is something else...")
}

class anime::tagTest {
    file { '/tmp/thisFileTag':
        ensure  => file,
        content => 'Some data',
        tag => 'tagTest' 
    }
}

class anime::scheduleTest {
    # Scheduling test...
    schedule { 'outofhours':
      period => 'daily',
      range  => '0100-0300',
    }

    service { 'foo':
      ensure   => running,
      schedule => 'outofhours',
    }
}

class anime::base {
	notify { "This is an anime module...": }
    $isThisAMac = $osfamily ? {
        'Darwin' => 'Yes',
        default  => 'No',
    }
	
    notify { "This is a Mac: ${isThisAMac}":}
    createUser{"newUser":}
}

class anime::base::test inherits anime::base {
    #deleteUser{"newUser":}
}

class anime {
    define deleteUser {
        notify { "Deleting a new user...":}
        user { "${title}": ensure => absent } 
    }

    define createUser {
        notify { "Creating a new user...":}
        user { "${title}": ensure => present }   
    }    

    require anime::base::test
    require anime::refresh
    require anime::runCmd
    require anime::testCondition
    require anime::scoping
    require anime::tagTest
}
