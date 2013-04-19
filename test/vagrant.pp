case $operatingsystem {
  centos, redhat, fedora: { 
    $pkgupdate = "yum clean all"
    $devsuffix = "devel"
  }
  debian, ubuntu: {
    $pkgupdate = "apt-get update"
    $devsuffix = "dev"
  }
}

exec {
  "update-packages":
    command => $pkgupdate,
    path => [ "/bin", "/usr/bin", "/sbin", "/usr/sbin" ];
}


file {
  # Sometimes veewee leaves behind this...
  "/EMPTY": ensure => absent, backup => false;
}

package {
  "git": ensure => latest;
  "bundler": provider => "gem", ensure => latest;
  "ruby-$devsuffix": ensure => latest;
}

File["/EMPTY"] -> Exec["update-packages"] -> Package <| |>
