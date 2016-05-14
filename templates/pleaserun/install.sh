#!/bin/sh

BASEDIR="<%= attributes[:prefix] %>"

silent() {
  "$@" > /dev/null 2>&1
}

install_files() {
  # TODO(sissel): Need to know what prefix the files exist at
  platform="$1"

  cp -Rp "${BASEDIR}/${platform}/files/" "/"
}

install_actions() {
  # TODO(sissel): Need to know what prefix the files exist at
  platform="$1"
  . "${BASEDIR}/${platform}/activate.sh"
}

has_systemd() {
  [ -d "/lib/systemd/system/" ] && silent which systemctl
}

has_upstart() {
  [ -d "/etc/init" ] && silent which initctl
}

has_sysv() {
  [ -d "/etc/init.d" ] 
}

has_freebsd_rcng() {
  [ -d "/etc/rc.d" ] && silent which rcorder
}

has_daemontools() {
  [ -d "/service" ] && silent which sv
}

has_launchd() { 
  [ -d "/Library/LaunchDaemons" ] && silent which launchtl
}

platforms="systemd upstart daemontools freebsd_rcng launchd sysv"
for platform in $platforms ; do
  if has_$platform ; then
    echo "Platform $platform detected.."
    install_files $platform
    install_actions $platform
    break
  fi
done
