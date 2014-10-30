class test::params {

  case $operatingsystem {
    'Darwin': {
	$package_name = 'TestDarwin'
    }
    default: {
        $package_name = 'TestDefault'
    }
  }
}
