#!/bin/sh

BASEDIR="<%= attributes[:prefix] %>"

silent() {
  "$@" > /dev/null 2>&1
}

install_files() {
  # TODO(sissel): Need to know what prefix the files exist at
  platform="$1"
  version="$(version_${platform})"

  (
    # TODO(sissel): Should I just rely on rsync for this stuff?
    #rsync -av "${BASEDIR}/${platform}/${version}/files/" /
    cd "${BASEDIR}/${platform}/${version}/files/" || exit 1
    find . -print0 \
      | xargs -0 -n1 sh -c 'd="${1##.}"; if [ ! -z "$d" ] ; then if [ -d "$1" -a ! -d "$d" ] ; then mkdir "$d"; fi; if [ -f "$1" ] ; then cp -p "$1" "$d" ; fi; fi' -
  )
}

install_actions() {
  # TODO(sissel): Need to know what prefix the files exist at
  platform="$1"
  version="$(version_${platform})"
  . "${BASEDIR}/${platform}/${version}/install_actions.sh"
}

version_systemd() {
  echo default
}

version_launchd() {
  echo 10.9
}

version_upstart() {
  echo "default"
}

version_sysv() {
  echo lsb-3.1
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

platforms="systemd upstart launchd sysv"
installed=0
for platform in $platforms ; do
  if has_$platform ; then
    version="$(version_$platform)"
    echo "Platform $platform ($version) detected. Installing service."
    install_files $platform
    install_actions $platform
    installed=1
    break
  fi
done

if [ "$installed" -eq 0 ] ; then
  echo "Failed to detect any service platform, so no service was installed. Files are available in ${BASEDIR} if you need them."
fi
