case $operatingsystem {
  centos, redhat, fedora: {
    $pkgupdate = "yum clean all"
    $devsuffix = "-devel"
  }
  debian, ubuntu: {
    $pkgupdate = "apt-get update"
    $devsuffix = "-dev"
    package {
      "lintian": ensure => latest
    }
  }
  Archlinux: {
    $pkgupdate = "pacman -Syu --noconfirm --needed"
    $devsuffix = "dev"
  }
}

exec {
  "update-packages":
    command => $pkgupdate,
    path => [ "/bin", "/usr/bin", "/sbin", "/usr/sbin" ],
    timeout => 14400
}

package {
  "git": ensure => latest;
  "bundler": provider => "gem", ensure => latest;
  "ruby$devsuffix": ensure => latest;
}

Exec["update-packages"] -> Package <| |>
