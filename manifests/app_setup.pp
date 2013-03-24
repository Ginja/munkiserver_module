class munkiserver_module::app_setup {  
  $user_path               = "/Users/${munkiserver_module::user}"
  $global_munkiserver_path = "${user_path}/.rvm/gems/ruby-1.9.3-p0/bin"
  $global_bin_path         = "${user_path}/.rvm/gems/ruby-1.9.3-p0@global/bin"
  $app_path                = "${munkiserver_module::path}/munkiserver"
  $gem_path                = "${user_path}}/.rvm/gems/ruby-1.9.3-p0@global"
  # Our SQL statements. Creates munkiserver db and user.
  $Q1  = "CREATE DATABASE IF NOT EXISTS ${munkiserver_module::db_name};"
  $Q2  = "GRANT ALL ON ${munkiserver_module::db_name}.* TO '${munkiserver_module::db_user}'@'localhost' IDENTIFIED BY '${munkiserver_module::db_pass}';"
  $Q3  = "FLUSH PRIVILEGES;"
  $SQL = "${Q1}${Q2}${Q3}"

  exec { 'git-cloning':
    command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c \"/usr/local/bin/git clone --progress git://github.com/jnraine/munkiserver.git &> /tmp/munkiserver/2_1_app_setup-git-cloning.log\"",
    cwd     => $munkiserver_module::path,
    timeout     => 0,
    creates => $app_path,
  }

  exec { 'remove-rvmrc':
    command => "/bin/rm -rf .rvmrc",
    cwd     => $app_path,
    onlyif  => '/bin/test -f .rvmrc',
    require => Exec['git-cloning'],
  }
  
  exec { 'app-installation':
    command  => "/usr/bin/sudo -u $munkiserver_module::user -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_bin_path}/bundle install &> /tmp/munkiserver/2_2_app_setup-app-installation.log'",
    cwd      => $app_path,
    unless   => "/usr/bin/sudo -u $munkiserver_module::user -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_bin_path}/bundle check'",
    require  => Exec['remove-rvmrc'],
  }

 file { 'database-copy':
   ensure  => present,
   path    => "${app_path}/config/database.yml",
   content => template('munkiserver_module/database.yml.erb'),
   owner   => $munkiserver_module::user,
   group   => 'admin',
   mode    => '0644',
   require => Exec['app-installation'],
 }

  if $munkiserver_module::db_host == 'localhost' {
    file { '/var/mysql':
      ensure  => directory,
      owner   => '_mysql',
      group   => 'admin',
      mode    => 0775,
      require => File['database-copy'],
    }

    file { $munkiserver_module::db_socket:
      ensure  => present,
      owner   => '_mysql',
      group   => 'admin',
      mode    => 0777,
      require => File['database-copy'], 
    }

    file { 'mysql-conf':
      ensure  => present,
      path    => '/etc/my.cnf',
      owner   => 'root',
      group   => 'wheel',
      mode    => 0644,
      content => template('munkiserver_module/my.cnf.erb'),
      require => File[$munkiserver_module::db_socket],
    }

    exec { 'mysql-install-db':
      command => '/usr/local/bin/mysql_install_db --basedir=/usr/local/opt/mysql --user=_mysql --ldata=/usr/local/var/mysql --verbose &> /tmp/munkiserver/2_3_app_setup-mysql-install-db.log',
      creates => '/usr/local/var/mysql',
      require => File['mysql-conf'],
    }

    file { 'mysql-launchd':
      path    => '/Library/LaunchDaemons/homebrew.mxcl.mysql.plist',
      ensure  => present,
      owner   => 'root',
      group   => 'wheel',
      mode    => 0644,
      source  => 'puppet:///modules/munkiserver_module/homebrew.mxcl.mysql.plist',
      require => Exec['mysql-install-db'],
    }

    # Good to sleep so we don't try to access the DB before it's fully operational
    exec { 'start-launchd':
      command   => '/bin/launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.mysql.plist && /bin/sleep 20',
      unless    => '/bin/launchctl list | grep homebrew.mxcl.mysql',
      subscribe => File['mysql-launchd'], 
    }

    exec { 'mysql-db-create':
      command => "/usr/local/bin/mysql -u root -e \"${SQL}\" &> /tmp/munkiserver/2_4_app_setup_mysql-db-create.log",
      unless  => "/usr/local/bin/mysql -u root -e 'show databases;' | grep ${munkiserver_module::db_name} && \
  		/usr/local/bin/mysql -u root -e 'select User from mysql.user;' | grep ${munkiserver_module::db_user}",
      require => Exec['start-launchd'],
    }
  }
 
 if $munkiserver_module::db_host == 'localhost' {
  exec { 'rake-migrate':
      command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_bin_path}/rake db:migrate RAILS_ENV=production &> /tmp/munkiserver/2_5_app_setup-rake-migrate.log'",
      cwd     => $app_path,
      creates => "${app_path}/log",
      user    => $munkiserver_module::user,    
      require => Exec['mysql-db-create'],
    }
  }
  else {
    exec { 'rake-migrate':
      command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_bin_path}/rake db:migrate RAILS_ENV=production &> /tmp/munkiserver/2_5_app_setup-rake-migrate.log'",
      cwd     => $app_path,
      creates => "${app_path}/log",
      user    => $munkiserver_module::user,    
      require => File['database-copy'],
    }
  }

  # Need to create app user and settings file so rake bootstrap doesn't expect stdin
  exec { 'app-root-user':
    command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c \"source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_munkiserver_path}/rails runner -e production 'User.create(:username => \\\"root\\\", :password => \\\"${munkiserver_module::app_pass}\\\", :password_confirmation => \\\"${munkiserver_module::app_pass}\\\", :email => \\\"root@${::fqdn}\\\", :super_user => true)' &> /tmp/munkiserver/2_6_app_setup-app-root-user.log\"",
    cwd     => $app_path,
    user    => $munkiserver_module::user,
    unless  => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c \"source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_munkiserver_path}/rails runner -e production 'puts User.all' | grep root\"",
    require => Exec['rake-migrate'],
  }

  exec { 'place-settings-yaml':
    command => '/bin/cp settings.default.yaml settings.yaml',
    cwd     => "${app_path}/config",
    user    => $munkiserver_module::user,
    creates => "${app_path}/config/settings.yaml",
    require => Exec['app-root-user'],
  }

  file { 'fill-settings-yaml':
    path    => "${app_path}/config/settings.yaml",
    ensure  => present,
    content => ":action_mailer: \n  :host: \"https://${::fqdn}\"",
    require => Exec['place-settings-yaml'],
  }

  exec { 'rake-bootstrap':
    command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_bin_path}/rake bootstrap:all RAILS_ENV=production &> /tmp/munkiserver/2_7_app_setup-rake-bootstrap.log'",
    cwd     => $app_path,
    creates => "${munkiserver_module::path}/munkiserver_assets",
    user    => $munkiserver_module::user,    
    require => File['fill-settings-yaml'],
  }

  exec { 'rake-assets':
    command => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source ${user_path}/.rvm/environments/ruby-1.9.3-p0; ${global_bin_path}/rake assets:precompile &> /tmp/munkiserver/2_8_app_setup-rake-assets.log'",
    cwd     => $app_path,
    creates => "${app_path}/public/assets",
    user    => $munkiserver_module::user,    
    require => Exec['rake-bootstrap'],
  }
}
