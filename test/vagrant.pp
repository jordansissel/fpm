case $operatingsystem {
  centos, redhat, fedora: {
    $pkgupdate = "yum clean all"
    $ruby_devel_pkg = "ruby-devel"
  }
  debian, ubuntu: {
    $pkgupdate = "apt-get update"
    $ruby_devel_pkg = "ruby-dev"
    package {
      "lintian": ensure => latest
    }
  }
  arch: {
    $pkgupdate = "yaourt --sucre"
    $ruby_devel_pkg = "ruby"
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
  $ruby_devel_pkg: ensure => latest;
}

Exec["update-packages"] -> Package <| |>