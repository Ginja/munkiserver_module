# == Define: munkiserver_module::vhost
#
# Places a vhost file(s) populated with values from the parameters of this class. It places the file in '/etc/apache2/other' or '/etc/apache2/sites'.
#
# === Parameters
#
# [*ssl_cert*]
#   The location of the SSL crt file.
# [*ssl_key*]
#   The location of the SSL key file.
# [*ssl_chain*]
#   The location of the SSL csr file.
# [*public_dir*]
#   The path to the munkiserver/public directory.
# [*pkg_store*]
#   The path to the munkiserver/packages directory.
# [*vhost*]
#   The vhost name. Default to '*'.
# [*port*]
#   The port to listen on. Defaults to '443'.
# [*svr_name*]
#   The DNS name you want your munkiserver application to respond to. This defaults to the FQDN of the machine.
# [*redirect_http*]
#   Whether or not you want to redirect all http traffic to the server to the munkiserver application. Defaults to 'false'.
#
# === Examples
#
# munkiserver_module::vhost { 'munkiserver':
#  ssl_cert  => '/etc/apache2/ssl/server.cert.pem',
#  ssl_key   => '/etc/apache2/ssl/server.key.pem',
#  ssl_chain => '/etc/apache2/ssl/server.chain.pem',
#  public_dir  => '/Library/WebServer/Documents/munkiserver/public',
#  pkg_store => '/Library/WebServer/Documents/munkiserver/packages',
#  vhost     => '*',
#  port      => '443',
# }
#
# === Authors
#
# Riley Shott <rshott@sfu.ca>
# 
define munkiserver_module::vhost ( $ssl_cert,
                                   $ssl_key,
                                   $ssl_chain,
                                   $public_dir, # /path/to/munkiserver/public
                                   $pkg_store, # /path/to/munkiserver/packages
                                   $vhost         = '*',
                                   $port          = '443',
                                   $svr_name      = $::fqdn,
                                   $redirect_http = false ) 
{
  if $redirect_http != true and $redirect_http != false {
    fail("The redirect_http parameter value must be true or false (no quotes) - ${redirect_http}")
  }

  $conf_dir = $::macosx_productname ? {
      'Mac OS X'        => 'other',
      'Mac OS X Server' => 'sites',
  }

  # Sometimes this folder doesn't exist on Mac OS X
  file { '/etc/apache2/other':
    ensure => directory,
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # The /etc/apache2 directory structure differs a little bit depending on your Mac OS X version.
  file { "${title}.conf":
    ensure  => $ensure,
    path    => "/etc/apache2/${conf_dir}/httpd-vhost-${title}.conf", 
    content => template('munkiserver_module/httpd-vhost-ssl-default.conf.erb'),
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
  }

  if $redirect_http == true {
    if $::macosx_productname == 'Mac OS X Server' {
      exec { 'remove-default-vhost':
        command => "/bin/rm -rf /etc/apache2/${conf_dir}/0000_any_80_.conf",
        onlyif  => "/bin/test -f /etc/apache2/${conf_dir}/0000_any_80_.conf",
      }
    }

    file { 'redirect-http':
      ensure      => present,
      path        => "/etc/apache2/${conf_dir}/httpd-vhost-default.conf",
      content     => template('munkiserver_module/httpd-vhost-default.conf.erb'),
      owner       => root,
    }
  }
  else {
    file { 'redirect-http':
      ensure      => absent,
      path        => "/etc/apache2/${conf_dir}/httpd-vhost-default.conf",
    }
  }

  exec { 'restart-apache':
    command     => "/usr/sbin/apachectl graceful",
    subscribe   => File["${title}.conf", 'redirect-http'],
    refreshonly => true,
  }
}
