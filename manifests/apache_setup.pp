class munkiserver_module::apache_setup {
  $user_path = "/Users/${munkiserver_module::user}"
  $rvm_path = "/Users/${munkiserver_module::user}/.rvm/bin"
  $pass_bin = "/Users/${munkiserver_module::user}/.rvm/gems/ruby-1.9.3-p0/bin"
  $pass_path = "${user_path}/.rvm/gems/ruby-1.9.3-p0/gems/passenger-${munkiserver_module::passenger_vers}"
  $conf_dir = $::macosx_productname ? {
      'Mac OS X'        => 'other',
      'Mac OS X Server' => 'sites',
  }
  
  # Install passenger gem
  exec { 'passenger-gem':
     command     => "${rvm_path}/gem-ruby-1.9.3-p0 install passenger -v '${munkiserver_module::passenger_vers}' &> /tmp/munkiserver/3_1_apache_setup-passenger-gem.log",
     environment => "HOME=${user_path}",
     creates     => "${pass_path}/bin/passenger",
     user        => $munkiserver_module::user,
   }

  # -a is needed otherwise it's an interactive install
  exec { 'passenger-apache':
    command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${pass_bin}/passenger-install-apache2-module -a &> /tmp/munkiserver/3_2_apache_setup-passenger-apache.log'",
    creates => "${pass_path}/ext/apache2/mod_passenger.so",
    require => Exec['passenger-gem'],
  }

  file { 'httpd-munkiserver-configs':
    ensure  => present,
    path    => "/etc/apache2/${conf_dir}/httpd-munkiserver.conf",
    content => template('munkiserver_module/httpd-munkiserver.conf.erb'),
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
  }

  file { 'mod-xsendfile-install':
    ensure  => present,
    path    => '/usr/libexec/apache2/mod_xsendfile.so',
    source  => 'puppet:///modules/munkiserver_module/mod_xsendfile.so',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0755',
    require => File['httpd-munkiserver-configs'],
  }

  exec { 'apachectl-restart':
    command     => '/usr/sbin/apachectl graceful',
    subscribe   => [ Exec['passenger-apache'], File['httpd-munkiserver-configs', 'mod-xsendfile-install'] ],
    refreshonly => true,
  }
}
