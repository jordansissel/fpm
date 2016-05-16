#!/bin/sh

source="<%= attributes[:prefix] %>"

cleanup_script="$source/cleanup.sh"

silent() {
  "$@" > /dev/null 2>&1
}

install_files() {
  # TODO(sissel): Need to know what prefix the files exist at
  platform="$1"
  version="$(version_${platform})"

  (
    # TODO(sissel): Should I just rely on rsync for this stuff?
    cd "${source}/${platform}/${version}/files/" || exit 1

    # Write a cleanup script
    find . -print0 | xargs -r0 -n1 "$source/generate-cleanup.sh" > "$cleanup_script"

    # Actually do the installation
    find . -print0 | xargs -r0 -n1 "$source/install-path.sh"
  )
}

install_actions() {
  # TODO(sissel): Need to know what prefix the files exist at
  platform="$1"
  version="$(version_${platform})"
  

  actions="${source}/${platform}/${version}/install_actions.sh"
  if [ -f "$actions" ] ; then
    . "$actions"
  fi
}

version_systemd() {
  # Treat all systemd versions the same
  echo default
}

version_launchd() {
  # Treat all launchd versions the same
  echo 10.9
}

version_upstart() {
  # Treat all upstart versions the same
  # TODO(sissel): Upstart 0.6.5 needs to be handled specially.
  version="$(initctl --version | head -1 | tr -d '()' | awk '{print $NF}')"

  case $version in
    0.6.5) echo $version ;;
    *) echo "1.5" ;; # default modern assumption
  esac
}

version_sysv() {
  # TODO(sissel): Once pleaserun supports multiple sysv implementations, maybe
  # we inspect the OS to find out what we should target.
  echo lsb-3.1
}

has_systemd() {
  # Some OS vendors put systemd in ... different places ...
  [ -d "/lib/systemd/system/" -o -d "/usr/lib/systemd/system" ] && silent which systemctl
}

has_upstart() {
  [ -d "/etc/init" ] && silent which initctl
}

has_sysv() {
  [ -d "/etc/init.d" ] 
}

#has_freebsd_rcng() {
  #[ -d "/etc/rc.d" ] && silent which rcorder
#}

has_daemontools() {
  [ -d "/service" ] && silent which sv
}

has_launchd() { 
  [ -d "/Library/LaunchDaemons" ] && silent which launchtl
}

install_help() {
  case $platform in
    systemd) echo "To start this service, use: systemctl start <%= attributes[:pleaserun_name] %>" ;;
    upstart) echo "To start this service, use: initctl start <%= attributes[:pleaserun_name] %>" ;;
    launchd) echo "To start this service, use: launchctl start <%= attributes[:pleaserun_name] %>" ;;
    sysv) echo "To start this service, use: /etc/init.d/<%= attributes[:pleaserun_name] %> start" ;;
  esac
}

platforms="systemd upstart launchd sysv"
installed=0
for platform in $platforms ; do
  if has_$platform ; then
    version="$(version_$platform)"
    echo "Platform $platform ($version) detected. Installing service."
    install_files $platform
    install_actions $platform
    install_help $platform
    installed=1
    break
  fi
done

if [ "$installed" -eq 0 ] ; then
  echo "Failed to detect any service platform, so no service was installed. Files are available in ${source} if you need them."
fi
