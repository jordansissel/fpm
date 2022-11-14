* ``--deb-activate EVENT``
    - Package activates EVENT trigger
* ``--deb-activate-noawait EVENT``
    - Package activates EVENT trigger
* ``--deb-after-purge FILE``
    - A script to be run after package removal to purge remaining (config) files (a.k.a. postrm purge within apt-get purge)
* ``--[no-]deb-auto-config-files``
    - Init script and default configuration files will be labeled as configuration files for Debian packages.
* ``--deb-build-depends DEPENDENCY``
    - Add DEPENDENCY as a Build-Depends
* ``--deb-changelog FILEPATH``
    - Add FILEPATH as debian changelog
* ``--deb-compression COMPRESSION``
    - The compression type to use, must be one of gz, bzip2, xz, none.
* ``--deb-config SCRIPTPATH``
    - Add SCRIPTPATH as debconf config file.
* ``--deb-custom-control FILEPATH``
    - Custom version of the Debian control file.
* ``--deb-default FILEPATH``
    - Add FILEPATH as /etc/default configuration
* ``--deb-dist DIST-TAG``
    - Set the deb distribution.
* ``--deb-field 'FIELD: VALUE'``
    - Add custom field to the control file
* ``--[no-]deb-generate-changes``
    - Generate PACKAGENAME.changes file.
* ``--deb-group GROUP``
    - The group owner of files in this package
* ``--[no-]deb-ignore-iteration-in-dependencies``
    - For '=' (equal) dependencies, allow iterations on the specified version. Default is to be specific. This option allows the same version of a package but any iteration is permitted
* ``--deb-init FILEPATH``
    - Add FILEPATH as an init script
* ``--deb-installed-size KILOBYTES``
    - The installed size, in kilobytes. If omitted, this will be calculated automatically
* ``--deb-interest EVENT``
    - Package is interested in EVENT trigger
* ``--deb-interest-noawait EVENT``
    - Package is interested in EVENT trigger without awaiting
* ``--[no-]deb-maintainerscripts-force-errorchecks``
    - Activate errexit shell option according to lintian. https://lintian.debian.org/tags/maintainer-script-ignores-errors.html
* ``--deb-meta-file FILEPATH``
    - Add FILEPATH to DEBIAN directory
* ``--[no-]deb-no-default-config-files``
    - Do not add all files in /etc as configuration files by default for Debian packages.
* ``--deb-pre-depends DEPENDENCY``
    - Add DEPENDENCY as a Pre-Depends
* ``--deb-priority PRIORITY``
    - The debian package 'priority' value.
* ``--deb-recommends PACKAGE``
    - Add PACKAGE to Recommends
* ``--deb-shlibs SHLIBS``
    - Include control/shlibs content. This flag expects a string that is used as the contents of the shlibs file. See the following url for a description of this file and its format: http://www.debian.org/doc/debian-policy/ch-sharedlibs.html#s-shlibs
* ``--deb-suggests PACKAGE``
    - Add PACKAGE to Suggests
* ``--deb-systemd FILEPATH``
    - Add FILEPATH as a systemd script
* ``--[no-]deb-systemd-auto-start``
    - Start service after install or upgrade
* ``--[no-]deb-systemd-enable``
    - Enable service on install or upgrade
* ``--[no-]deb-systemd-restart-after-upgrade``
    - Restart service after upgrade
* ``--deb-templates FILEPATH``
    - Add FILEPATH as debconf templates file.
* ``--deb-upstart FILEPATH``
    - Add FILEPATH as an upstart script
* ``--deb-upstream-changelog FILEPATH``
    - Add FILEPATH as upstream changelog
* ``--[no-]deb-use-file-permissions``
    - Use existing file permissions when defining ownership and modes
* ``--deb-user USER``
    - The owner of files in this package

