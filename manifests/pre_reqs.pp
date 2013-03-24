class munkiserver_module::pre_reqs {
  $user_path = "/Users/${munkiserver_module::user}"
  $rvm_bin = "${user_path}/.rvm/bin"

  user { $munkiserver_module::user:
    ensure            => present,
    gid               => '80',
    home              => $user_path,
    provider          => 'directoryservice',
    shell             => '/bin/bash',
  }

  file { 'home-dir':
    path    => $user_path,
    ensure  => 'directory',
    group   => 'admin',
    owner   => $munkiserver_module::user,
    mode    => 0644,
    require => User[$munkiserver_module::user],
  }

  # GCC is needed for both homebrew and rvm
  if $::has_compiler == 'false' {
    exec {'get-gcc':
      command => "/usr/bin/curl -o /tmp/munkiserver/gcc.pkg ${munkiserver_module::gcc}",
      creates => '/tmp/munkiserver/gcc.pkg',
    }

    package {'GCC-install':
      ensure => installed,
      provider => apple,
      source => '/tmp/munkiserver/gcc.pkg',
      require => Exec['get-gcc'],
      before => [ Exec['rvm-install'], Class['homebrew'] ],
    }
  }

  exec { 'rvm-install':
    command     => "/usr/bin/curl -Ls https://get.rvm.io -o /tmp/install_rvm && /bin/chmod +x /tmp/install_rvm && /tmp/install_rvm --version latest &> /tmp/munkiserver/1_1_pre_reqs-rvm-install.log && /bin/rm -rf /tmp/install_rvm",
    user        => $munkiserver_module::user,
    environment => "HOME=${user_path}",
    creates     => "${rvm_bin}/rvm",
    require     => File['home-dir'],
  }

  # munkiserver user needs to be a part of this group for installing things with rvm
  group { 'rvm':
    members  => $munkiserver_module::user,
    provider => 'directoryservice', 
    require  => Exec['rvm-install'],
  }

  # Installing ruby 1.9.3 with rvm. Also takes a long time to install, disabled timeout
  exec { 'install-ruby-1.9.3-p0':
    command     => "${rvm_bin}/rvm install 1.9.3-p0 &> /tmp/munkiserver/1_2_pre_reqs-install-ruby-1.9.3-p0.log",
    user        => $munkiserver_module::user,
    environment => "HOME=${user_path}",
    creates     => "${user_path}/.rvm/wrappers/ruby-1.9.3-p0/ruby",
    timeout     => 0,
    require     => Group['rvm'],
  }
  
  # Ensuring ruby 1.9.3 is set to default for our munkiserver user
  exec { 'ruby-1.9.3-p0-default':
    command   => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source \"\$HOME/.rvm/scripts/rvm\" && rvm use 1.9.3-p0 --default &> /tmp/munkiserver/1_3_pre_reqs-ruby-1.9.3-p0-default.log'",
    cwd       => $user_path,
    unless    => "/usr/bin/sudo -u ${munkiserver_module::user} -H bash -c 'source \"\$HOME/.rvm/scripts/rvm\" && `which ruby` --version | grep 1.9.3'",
    subscribe => Exec['install-ruby-1.9.3-p0'],
  }

  # Install bundler gem
  exec { 'bundler-gem':
    command     => "${rvm_bin}/gem-ruby-1.9.3-p0 install bundler &> /tmp/munkiserver/1_4_pre_reqs-bundler-gem.log",
    user        => $munkiserver_module::user,
    environment => "HOME=${user_path}",
    cwd         => $user_path,
    creates     => "${user_path}/.rvm/gems/ruby-1.9.3-p0/bin/bundle",
    require     => Exec['ruby-1.9.3-p0-default'],
  }

  # Installing munkitools 
  package { 'munkitools-install':
    ensure   => installed,
    provider => pkgdmg,
    source   => $munkiserver_module::munkitools,
  }

  if $::has_x11 == 'false' {
    # Installing XQuartz (needed for Homebrew if X11 isn't installed)
    package { 'XQuartz-install':
      ensure   => installed,
      provider => pkgdmg,
      source   => $munkiserver_module::xquartz,
    }
    # Installing homebrew
    class { 'homebrew':
      user    => $munkiserver_module::user,    # Defaults to 'root', which is not recommended.
      require => [ File['home-dir'], Package['XQuartz-install'] ],
    }
  }
  else {
    # Installing homebrew
    class { 'homebrew':
      user    => $munkiserver_module::user,    # Defaults to 'root', which is not recommended.
      require => File['home-dir'],
    }
  }

  exec {'git-homebrew':
    command     => "/usr/local/bin/brew install git &> /tmp/munkiserver/1_5_pre_reqs-git-homebrew.log",
    user        => $munkiserver_module::user,
    environment => "HOME=${user_path}",
    creates     => '/usr/local/Cellar/git',
    require     => Class['homebrew'],
  }

  # Update brew for good measure
  exec {'brew-update':
    command     => '/usr/local/bin/brew update &> /tmp/munkiserver/1_6_pre_reqs-brew-update.log',
    user        => $munkiserver_module::user,
    environment => "HOME=${user_path}",
    creates     => '/usr/local/.git',
    require     => [ Class['homebrew'], Exec['git-homebrew'] ],
  }

  exec {'imagemagick-homebrew':
    command     => "/usr/local/bin/brew install imagemagick &> /tmp/munkiserver/1_7_pre_reqs-imagemagick-homebrew.log",
    user        => $munkiserver_module::user,
    environment => "HOME=${user_path}",
    creates     => '/usr/local/Cellar/imagemagick',
    require     => [ Class['homebrew'], Exec['brew-update'] ],
  }

  if $munkiserver_module::db_host == 'localhost' {
    # mysql takes a long time to install, too long for puppet sometimes. Disabled timeout
    exec {'mysql-homebrew':
      command     => "/usr/local/bin/brew install mysql &> /tmp/munkiserver/1_8_pre_reqs-mysql-homebrew.log",
      user        => $munkiserver_module::user,
      environment => "HOME=${user_path}",
      creates     => '/usr/local/Cellar/mysql',
      timeout     => 0,
      require     => [ Class['homebrew'], Exec['brew-update'] ],
    }
  }
}
