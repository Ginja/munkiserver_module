# == Class: munkiserver_module
#
# This module will install and configure a munkiserver app instance. You need to do several things before you use it:
# Install bjoernalbers-homebrew module (on your puppet master or locally if you're using a local manifest.)
# Create an SSL key, chain, and cert on target machine (preferably with the key un-encrypted, otherwise you'll need to enter your passphrase everytime apache is restarted)
# Install the XCode Command Line Tools on your target machine (optional)
#
# === Parameters
#
# [*app_pass*]
#   The password that will be set for the root user of the munkiserver app. Must be between 5-24 characters. This can be changed via the application GUI afterwards.
# [*db_pass*]
#   The password that will be set for the mysql database user. If you will be managing the state of your server with this puppet module afterwards, this cannot be changed once set.
# [*apache*]
#   Boolean flag to specify whether or not to use apache/passenger to handle https requests. If you specify true ensure you declare a munkiserver_module::vhost resource.
# [*user*]
#   This will be the local user that the application is configured under. If the user does not exist the module will create it (recommended). If the module creates a local user there will be no password for the account. To become the user you'll need to su to it from root. The default value is 'munkiserver'.
# [*path*]
#   The path where the munkiserver app will be downloaded. Defaults to '/Library/WebServer/Documents'.
# [*munkitools*]
#   Download location for munkitools. If you specify your own location make sure it's a dmg. Defaults to the latest stable version at this time 'http://munki.googlecode.com/files/munkitools-0.8.3.1679.0.dmg'.
# [*xquartz*]
#   Download location for XQuartz. If you specify your own location make sure it's a dmg. Defaults to the latest version at this time 'http://xquartz.macosforge.org/downloads/SL/XQuartz-2.7.4.dmg'.
# [*gcc*]
#   Download location for the gcc compiler. Will only be installed if the XCode Command Line Tools haven't been. If you specify your own location make sure it's a pkg. Defaults to the appropiate package for your Mac OS X version (should never need to set this, unless the download location changes).
# [*adapter*]
#   The db adapter to use for the munkiserver app. Change at your own risk. Defaults to 'mysql2'.
# [*db_host*]
#   The host of the mysql db. Defaults to 'localhost'.
# [*db_name*]
#   The name of the mysql database that will be created and used for the munkiserver application. Defaults to 'munkiserver'.
# [*db_user*]
#   The name of the mysql user that the application will create and use. Defaults to 'munki'.
# [*passenger_vers*]
#   The version of Phusion Passenger you want to install. This parameter will only be taken into consideration if the apache parameter is set to true. You can also only specify stable versions. Defaults to the latest stable version at this time, '3.0.19'.
#
# === Examples
#
# class { 'munkiserver_module':
#   app_pass       => '12345',
#   db_pass        => 'makethishardtoguess',
#   apache         => true,
#   user           => 'munkiserver',
#   path           => '/Library/WebServer/Documents',
#   passenger_vers => '3.0.19'
# }
#
# munkiserver_module::vhost { 'munkiserver':
#   ssl_cert      => '/etc/apache2/ssl/server.cert.pem',
#   ssl_key       => '/etc/apache2/ssl/server.key.pem',
#   ssl_chain     => '/etc/apache2/ssl/server.chain.pem',
#   public_dir    => '/Library/WebServer/Documents/munkiserver/public',
#   pkg_store     => '/Library/WebServer/Documents/munkiserver/packages',
#   vhost         => '*',
#   port          => '443',
#   svr_name      => 'fqdn.here.com',
#   redirect_http => true,
# }
#
# === Authors
#
# Riley Shott <rshott@sfu.ca>
#
class munkiserver_module ( $app_pass,
                           $db_pass,
                           $apache,
                           $user             = $munkiserver_module::params::user,
                           $path             = $munkiserver_module::params::path,
                           $munkitools       = $munkiserver_module::params::munkitools,
                           $xquartz          = $munkiserver_module::params::xquartz,
                           $gcc              = $munkiserver_module::params::gcc,
                           $adapter          = $munkiserver_module::params::adapter,
                           $db_host          = $munkiserver_module::params::db_host,
                           $db_name          = $munkiserver_module::params::db_name,
                           $db_user          = $munkiserver_module::params::db_user,
                           $db_socket        = $munkiserver_module::params::db_socket, 
                           $passenger_vers   = $munkiserver_module::params::passenger_vers ) inherits munkiserver_module::params
{
    # Fail early, fail hard
  if $apache != true and $apache != false {
    fail("The apache parameter value must be true or false (no quotes) - ${apache} ")
  }

  $tmp = inline_template("<%= app_pass.length %>")
  if $tmp < 5 or $tmp > 24 {
    fail("The app_pass parameter must be between 5-24 characters - ${app_pass} ")
  }

  if $::has_compiler == nil {
    fail('It appears there is no Homebrew module, please install one - EX: puppet module install bjoernalbers-homebrew ')
  }

  # Create a nice tmp directory to store all the logs generated by this module's resource types
  file { 'tmp-directory':
    path   => '/tmp/munkiserver',
    ensure => directory,
    mode   => 0777,
  }

  # Main action
  if $apache {
    stage { 'post_first': require   => Stage['main'] }
    stage { 'post_second':  require => Stage['post_first'] }
    stage { 'post_third': require   => Stage['post_second'] } 
  }
  else {
    stage { 'post_first': require   => Stage['main'] }
    stage { 'post_second':  require => Stage['post_first'] }
  }

  class { 'munkiserver_module::pre_reqs':  stage    => post_first }
  class { 'munkiserver_module::app_setup':  stage    => post_second }
  class { 'munkiserver_module::apache_setup':  stage => post_third }
}
