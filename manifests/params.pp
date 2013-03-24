class munkiserver_module::params {

  if $::operatingsystem != 'Darwin' {
    fail("This module doesn't support this operating system - ${::operatingsystem} ")
  } 

  $apache         = false
  $user           = 'munkiserver'
  $path           = '/Library/WebServer/Documents'
  $munkitools     = 'http://munki.googlecode.com/files/munkitools-0.8.3.1679.0.dmg'
  $xquartz        = 'http://xquartz.macosforge.org/downloads/SL/XQuartz-2.7.4.dmg'
  $gcc = $::macosx_productversion_major ? {
    	  '10.6' => 'http://cloud.github.com/downloads/kennethreitz/osx-gcc-installer/GCC-10.6.pkg',
    	  '10.7' => 'http://cloud.github.com/downloads/kennethreitz/osx-gcc-installer/GCC-10.7-v2.pkg',
    	  '10.8' => 'http://cloud.github.com/downloads/kennethreitz/osx-gcc-installer/GCC-10.7-v2.pkg',
  }
  $adapter        = 'mysql2'
  $db_host        = 'localhost'
  $db_name        = 'munkiserver'
  $db_user        = 'munki'
  $db_socket      = '/var/mysql/mysql.sock'
  $passenger_vers = '3.0.19'
}