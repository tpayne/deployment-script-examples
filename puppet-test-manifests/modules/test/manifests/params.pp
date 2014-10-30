class test::params {

  case $operatingsystem {
    'Darwin': {
	$package_name = 'TestDarwin'
        $tomcat_home = '/Library/Tomcat/'
    }
    default: {
        $package_name = 'TestDefault'
	$tomcat_home = '/opt/tomcat/'
    }
  }
}
