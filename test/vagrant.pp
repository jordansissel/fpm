case $operatingsystem {
  centos, redhat, fedora: {
    $pkgupdate = "yum clean all"
    $devsuffix = "devel"
  }
  debian, ubuntu: {
    $pkgupdate = "apt-get update"
    $devsuffix = "dev"
    package {
      "lintian": ensure => latest
    }
  }
}

exec {
  "update-packages":
    command => $pkgupdate,
    path => [ "/bin", "/usr/bin", "/sbin", "/usr/sbin" ];
}

package {
  "git": ensure => latest;
  "bundler": provider => "gem", ensure => latest;
  "ruby-$devsuffix": ensure => latest;
}

Exec["update-packages"] -> Package <| |>
