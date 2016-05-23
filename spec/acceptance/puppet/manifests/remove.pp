node default {
  $package_provider = "$operatingsystem-$operatingsystemrelease" ? {
    /^(Fedora|RedHat|CentOS)/ => "rpm",
    /^(Debian|Ubuntu)/ => "dpkg",
    default => undef,
  }

  $service_provider = "$operatingsystem-$operatingsystemrelease" ? {
    /^CentOS-6/ => "upstart",
    default => undef,
  }

  package {
    "example-service": 
      require => Service["example"],
      provider => $package_provider,
      source => "example-service-1.0-1.noarch.rpm",
      ensure => absent;
  }

  service {
    "example":
      provider => $service_provider,
      enable => false,
      ensure => stopped;
  }
}
