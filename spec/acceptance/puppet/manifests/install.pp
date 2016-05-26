node default {
  $package_provider = "$operatingsystem-$operatingsystemrelease" ? {
    /^(Fedora|RedHat|CentOS|OpenSuSE)/ => "rpm",
    /^(Debian|Ubuntu)/ => "dpkg",
    default => undef,
  }
 
  $package_source = "$operatingsystem-$operatingsystemrelease" ? {
    /^(Fedora|RedHat|CentOS|OpenSuSE)/ => "example-service-1.0-1.noarch.rpm",
    /^(Debian|Ubuntu)/ => "example-service_1.0_all.deb",
    default => undef,
  }

  $service_provider = "$operatingsystem-$operatingsystemrelease" ? {
    /^CentOS-6/ => "upstart",
    default => undef,
  }

  

  package {
    "example-service": 
      provider => $package_provider,
      source => $package_source,
      ensure => present;
  }

  service {
    "example":
      provider => $service_provider,
      require => Package["example-service"],
      enable => true,
      ensure => running;
  }
}
