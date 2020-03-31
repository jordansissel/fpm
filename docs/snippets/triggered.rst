Debian Triggers
===============

Debian packages can install commands to be run after installation and configuration of all packages.
Those commands are called triggers as other packages can ask the package manager to run those.

Sample trigger script
---------------------

This script defines two triggers. First the label based trigger `some-trigger` which runs `some-command`. Second the path based trigger `/etc/foobar` which runs a find-command.

::

  for trigger in "$@"; do
    case "$trigger" in
      some-trigger)
        some-command
      ;;
      /etc/foobar)
        find /etc/foobar -type f -ls
      ;;
    esac
  done

Install trigger
---------------

The following fpm command installs the trigger:

    fpm --triggered /path/to/triggers.sh

The resulting postinst-script in the packages looks like this:

::

  #!/bin/sh
  
  after_upgrade() {
      :
  }
  
  after_install() {
      :
  }
  
  triggered() {
      :
  for trigger in "$@"; do
    case "$trigger" in
      some-trigger)
        some-command
      ;;
      /etc/foobar)
        find /etc/foobar -type f -ls
      ;;
    esac
  done
  }
  
  if [ "${1}" = "configure" -a -z "${2}" ] || \
     [ "${1}" = "abort-remove" ]
  then
      # "after install" here
      # "abort-remove" happens when the pre-removal script failed.
      #   In that case, this script, which should be idemptoent, is run
      #   to ensure a clean roll-back of the removal.
      after_install
  elif [ "${1}" = "configure" -a -n "${2}" ]
  then
      upgradeFromVersion="${2}"
      # "after upgrade" here
      # NOTE: This slot is also used when deb packages are removed,
      # but their config files aren't, but a newer version of the
      # package is installed later, called "Config-Files" state.
      # basically, that still looks a _lot_ like an upgrade to me.
      after_upgrade "${2}"
  elif [ "${1}" = "triggered" ]
  then
      # "triggered" here
      # NOTE: This slot allows implementing package triggers according to
      # https://wiki.debian.org/DpkgTriggers
      shift
      triggered "${@}"
  elif echo "${1}" | grep -E -q "(abort|fail)"
  then
      echo "Failed to install before the post-installation script was run." >&2
      exit 1
  fi
