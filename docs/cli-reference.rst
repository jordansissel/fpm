CLI Reference
=============

Documentation for all CLI flags

Usage
-----
	FPM [OPTIONS] [ARGS] ...

Parameters
----------

	[ARGS] ...
		
	* Inputs to the source package type. For the 'dir' type, this is the files and directories you want to include in the package. For others, like 'gem', it specifies the packages to download and use as the gem input.

Options
-------
    
* ``-t, --output-type OUTPUT_TYPE``
	- the type of package you want to create (deb, rpm, solaris, etc)
* ``-s, --input-type INPUT_TYPE``
	- The package type to use as input (gem, rpm, python, etc)
* ``-C, --chdir CHDIR``
	- Change directory to here before searching for files
* ``--prefix PREFIX``
	- A path to prefix files with when building the target package. This may not be necessary for all input packages. For example, the 'gem' type will prefix with your gem directory automatically.
* ``-p, --package OUTPUT``
	- The package file path to output.
* ``-f, --force``
	- Force output even if it will overwrite an existing file (default: false)
* ``-n, --name NAME``
	- The name to give to the package
* ``--log LEVEL``
	- Set the log level. Values: error, warn, info, debug.
* ``--verbose``
	- Enable verbose output
* ``--debug``
	- Enable debug output
* ``--debug-workspace``
	- Keep any file workspaces around for debugging. This will disable automatic cleanup of package staging and build paths. It will also print which directories are available.
* ``-v, --version VERSION``
	- The version to give to the package (default: 1.0)
* ``--iteration ITERATION``
	- The iteration to give to the package. RPM calls this the 'release'. FreeBSD calls it 'PORTREVISION'. Debian calls this 'debian_revision'
* ``--epoch EPOCH``
	- The epoch value for this package. RPM and Debian calls this 'epoch'. FreeBSD calls this 'PORTEPOCH'
* ``--license LICENSE``
	- (optional) license name for this package
* ``--vendor VENDOR``
	- (optional) vendor name for this package
* ``--category CATEGORY``
	- (optional) category this package belongs to (default: "none")
* ``-d, --depends DEPENDENCY``
	- A dependency. This flag can be specified multiple times. Value is usually in the form of: -d 'name' or -d 'name > version'
* ``--no-depends``
	- Do not list any dependencies in this package (default: false)
* ``--no-auto-depends``
	- Do not list any dependencies in this package automatically (default: false)
* ``--provides PROVIDES``
	- What this package provides (usually a name). This flag can be specified multiple times.
* ``--conflicts CONFLICTS``
	- Other packages/versions this package conflicts with. This flag can be specified multiple times.
* ``--replaces REPLACES``
	- Other packages/versions this package replaces. Equivalent of rpm's 'Obsoletes'. This flag can be specified multiple times.
* ``--config-files CONFIG_FILES``
	- Mark a file in the package as being a config file. This uses 'conffiles' in debs and %config in rpm. If you have multiple files to mark as configuration files, specify this flag multiple times.  If argument is directory all files inside it will be recursively marked as config files.
* ``--directories DIRECTORIES``
	- Recursively mark a directory as being owned by the package. Use this flag multiple times if you have multiple directories and they are not under the same parent directory 
* ``-a, --architecture ARCHITECTURE``
	- The architecture name. Usually matches 'uname -m'. For automatic values, you can use '-a all' or '-a native'. These two strings will be translated into the correct value for your platform and target package type.
* ``-m, --maintainer MAINTAINER``
	- The maintainer of this package. (default: "<user@hostname>")
* ``-S, --package-name-suffix PACKAGE_NAME_SUFFIX``
	- A name suffix to append to package and dependencies, e.g.: '-git', '-bin', etc.
* ``-e, --edit``
	- Edit the package spec before building. (default: false)
* ``-x, --exclude EXCLUDE_PATTERN ``
	- Exclude paths matching pattern (shell wildcard globs valid here). If you have multiple file patterns to exclude, specify this flag multiple times.
* ``--exclude-file EXCLUDE_PATH``
	- The path to a file containing a newline-sparated list of patterns to exclude from input.
* ``--description DESCRIPTION``
	- Add a description for this package. You can include '\n' sequences to indicate newline breaks. (default: "no description")
* ``--url URI``
	- Add a url for this package. (default: "http://example.com/no-uri-given")
* ``--inputs INPUTS_PATH``
	- The path to a file containing a newline-separated list of files and dirs to use as input.
* ``--after-install FILE``
	- A script to be run after package installation
* ``--before-install FILE``
	- A script to be run before package installation
* ``--after-remove FILE``
	- A script to be run after package removal
* ``--before-remove FILE``
	- A script to be run before package removal
* ``--after-upgrade FILE``
	- A script to be run after package upgrade. If not specified, --before-install, --after-install, --before-remove, and --after-remove will behave in a backwards-compatible manner (they will not be upgrade-case aware). Currently only supports deb, rpm and pacman packages.
* ``--before-upgrade FILE``
	- A script to be run before package upgrade. If not specified, --before-install, --after-install, --before-remove, and --after-remove will behave in a backwards-compatible manner (they will not be upgrade-case aware). Currently only supports deb, rpm and pacman packages.
* ``--template-scripts``
	- Allow scripts to be templated. This lets you use ERB to template your packaging scripts (for --after-install, etc). For example, you can do things like <%= name %> to get the package name. For more information, see the FPM wiki: https://github.com/jordansissel/fpm/wiki/Script-Templates
* ``--template-value KEY=VALUE``
	- Make 'key' available in script templates, so <%= key %> given will be the provided value. Implies --template-scripts
* ``--workdir WORKDIR``
	- The directory you want FPM to do its work in, where 'work' is any file copying, downloading, etc. Roughly any scratch space FPM needs to build your package. (default: "/tmp")
* ``--source-date-epoch-from-changelog``
	- Use release date from changelog as timestamp on generated files to reduce nondeterminism. Experimental; only implemented for gem so far.  (default: false)
* ``--source-date-epoch-default SOURCE_DATE_EPOCH_DEFAULT``
	- If no release date otherwise specified, use this value as timestamp on generated files to reduce nondeterminism. Reproducible build environments such as dpkg-dev and rpmbuild set this via envionment variable SOURCE_DATE_EPOCH variable to the integer unix timestamp to use in generated archives, and expect tools like FPM to use it as a hint to avoid nondeterministic output. This is a Unix timestamp, i.e. number of seconds since 1 Jan 1970 UTC. See https://reproducible-builds.org/specs/source-date-epoch  (default: $SOURCE_DATE_EPOCH)
* ``--gem-bin-path DIRECTORY``
	- (gem only) The directory to install gem executables
* ``--gem-package-name-prefix PREFIX``
	- (gem only) Name to prefix the package name with. (default: "rubygem")
* ``--gem-gem PATH_TO_GEM``
	- (gem only) The path to the 'gem' tool (defaults to 'gem' and searches your $PATH) (default: "gem")
* ``--gem-shebang SHEBANG``
	- (gem only) Replace the shebang in the executables in the bin path with a custom string (default: nil)
* ``--[no-]gem-fix-name``
	- (gem only) Should the target package name be prefixed? (default: true)
* ``--[no-]gem-fix-dependencies``
	- (gem only) Should the package dependencies be prefixed? (default: true)
* ``--[no-]gem-env-shebang``
	- (gem only) Should the target package have the shebang rewritten to use env? (default: true)
* ``--[no-]gem-prerelease``
	- (gem only) Allow prerelease versions of a gem (default: false)
* ``--gem-disable-dependency gem_n``
	- ame (gem only) The gem name to remove from dependency list
* ``--[no-]gem-embed-dependencies ``
	- (gem only) Should the gem dependencies be installed? (default: false)
* ``--[no-]gem-version-bins``
	- (gem only) Append the version to the bins (default: false)
* ``--gem-stagingdir STAGINGDIR``
	- (gem only) The directory where FPM installs the gem temporarily before conversion. Normally a random subdirectory of workdir.
* ``--gem-git-repo GIT_REPO``
	- (gem only) Use this git repo address as the source of the gem instead of rubygems.org. (default: nil)
* ``--gem-git-branch GIT_BRANCH``
	- (gem only) When using a git repo as the source of the gem instead of rubygems.org, use this git branch. (default: nil)
* ``--[no-]deb-ignore-iteration-in-dependencies``
	- (deb only) For '=' (equal) dependencies, allow iterations on the specified version. Default is to be specific. This option allows the same version of a package but any iteration is permitted
* ``--deb-build-depends DEPENDENCY``
	- (deb only) Add DEPENDENCY as a Build-Depends
* ``--deb-pre-depends DEPENDENCY  ``
	- (deb only) Add DEPENDENCY as a Pre-Depends
* ``--deb-compression COMPRESSION ``
	- (deb only) The compression type to use, must be one of gz, bzip2, xz, none. (default: "gz")
* ``--deb-dist DIST-TAG``
	- (deb only) Set the deb distribution. (default: "unstable")
* ``--deb-custom-control FILEPATH ``
	- (deb only) Custom version of the Debian control file.
* ``--deb-config SCRIPTPATH``
	- (deb only) Add SCRIPTPATH as debconf config file.
* ``--deb-templates FILEPATH``
	- (deb only) Add FILEPATH as debconf templates file.
* ``--deb-installed-size KILOBYTES``
	- (deb only) The installed size, in kilobytes. If omitted, this will be calculated automatically
* ``--deb-priority PRIORITY``
	- (deb only) The debian package 'priority' value. (default: "extra")
* ``--[no-]deb-use-file-permissions``
	- (deb only) Use existing file permissions when defining ownership and modes
* ``--deb-user USER``
	- (deb only) The owner of files in this package (default: "root")
* ``--deb-group GROUP``
	- (deb only) The group owner of files in this package (default: "root")
* ``--deb-changelog FILEPATH``
	- (deb only) Add FILEPATH as debian changelog
* ``--[no-]deb-generate-changes``
	- (deb only) Generate PACKAGENAME.changes file. (default: false)
* ``--deb-upstream-changelog FILEPATH``
	- (deb only) Add FILEPATH as upstream changelog
* ``--deb-recommends PACKAGE``
	- (deb only) Add PACKAGE to Recommends
* ``--deb-suggests PACKAGE``
	- (deb only) Add PACKAGE to Suggests
* ``--deb-meta-file FILEPATH``
	- (deb only) Add FILEPATH to DEBIAN directory
* ``--deb-interest EVENT``
	- (deb only) Package is interested in EVENT trigger
* ``--deb-activate EVENT``
	- (deb only) Package activates EVENT trigger
* ``--deb-interest-noawait EVENT  ``
	- (deb only) Package is interested in EVENT trigger without awaiting
* ``--deb-activate-noawait EVENT  ``
	- (deb only) Package activates EVENT trigger
* ``--deb-field 'FIELD: VALUE``
	- (deb only) Add custom field to the control file
* ``--[no-]deb-no-default-config-files``
	- (deb only) Do not add all files in /etc as configuration files by default for Debian packages. (default: false)
* ``--[no-]deb-auto-config-files  ``
	- (deb only) Init script and default configuration files will be labeled as configuration files for Debian packages. (default: true)
* ``--deb-shlibs SHLIBS``
	- (deb only) Include control/shlibs content. This flag expects a string that is used as the contents of the shlibs file. See the following url for a description of this file and its format: http://www.debian.org/doc/debian-policy/ch-sharedlibs.html#s-shlibs
* ``--deb-init FILEPATH``
	- (deb only) Add FILEPATH as an init script
* ``--deb-default FILEPATH``
	- (deb only) Add FILEPATH as /etc/default configuration
* ``--deb-upstart FILEPATH``
	- (deb only) Add FILEPATH as an upstart script
* ``--deb-systemd FILEPATH``
	- (deb only) Add FILEPATH as a systemd script
* ``--[no-]deb-systemd-enable``
	- (deb only) Enable service on install or upgrade (default: false)
* ``--[no-]deb-systemd-auto-start ``
	- (deb only) Start service after install or upgrade (default: false)
* ``--[no-]deb-systemd-restart-after-upgrade``
	- (deb only) Restart service after upgrade (default: true)
* ``--deb-after-purge FILE``
	- (deb only) A script to be run after package removal to purge remaining (config) files (a.k.a. postrm purge within apt-get purge)
* ``--[no-]deb-maintainerscripts-force-errorchecks``
	- (deb only) Activate errexit shell option according to lintian. https://lintian.debian.org/tags/maintainer-script-ignores-errors.html (default: false)
* ``--npm-bin NPM_EXECUTABLE``
	- (npm only) The path to the npm executable you wish to run. (default: "npm")
* ``--npm-package-name-prefix PREFIX``
	- (npm only) Name to prefix the package name with. (default: "node")
* ``--npm-registry NPM_REGISTRY``
	- (npm only) The npm registry to use instead of the default.
* ``--[no-]rpm-use-file-permissions``
	- (rpm only) Use existing file permissions when defining ownership and modes.
* ``--rpm-user USER``
	- (rpm only) Set the user to USER in the %files section. Overrides the user when used with use-file-permissions setting.
* ``--rpm-group GROUP``
	- (rpm only) Set the group to GROUP in the %files section. Overrides the group when used with use-file-permissions setting.
* ``--rpm-defattrfile ATTR``
	- (rpm only) Set the default file mode (%defattr). (default: "-")
* ``--rpm-defattrdir ATTR``
	- (rpm only) Set the default dir mode (%defattr). (default: "-")
* ``--rpm-rpmbuild-define DEFINITION``
	- (rpm only) Pass a --define argument to rpmbuild.
* ``--rpm-dist DIST-TAG``
	- (rpm only) Set the rpm distribution.
* ``--rpm-digest md5|sha1|sha256|sha384|sha512``
	- (rpm only) Select a digest algorithm. md5 works on the most platforms. (default: "md5")
* ``--rpm-compression-level [0-9] ``
	- (rpm only) Select a compression level. 0 is store-only. 9 is max compression. (default: "9")
* ``--rpm-compression none|xz|xzmt``
	- |gzip|bzip2 (rpm only) Select a compression method. gzip works on the most platforms. (default: "gzip")
* ``--rpm-os OS``
	- (rpm only) The operating system to target this rpm for. You want to set this to 'linux' if you are using FPM on OS X, for example
* ``--rpm-changelog FILEPATH``
	- (rpm only) Add changelog from FILEPATH contents
* ``--rpm-summary SUMMARY``
	- (rpm only) Set the RPM summary. Overrides the first line on the description if set
* ``--[no-]rpm-sign``
	- (rpm only) Pass --sign to rpmbuild
* ``--[no-]rpm-auto-add-directories``
	- (rpm only) Auto add directories not part of filesystem
* ``--rpm-auto-add-exclude-directories DIRECTORIES``
	- (rpm only) Additional directories ignored by '--rpm-auto-add-directories' flag
* ``--[no-]rpm-autoreqprov``
	- (rpm only) Enable RPM's AutoReqProv option
* ``--[no-]rpm-autoreq``
	- (rpm only) Enable RPM's AutoReq option
* ``--[no-]rpm-autoprov``
	- (rpm only) Enable RPM's AutoProv option
* ``--rpm-attr ATTRFILE``
	- (rpm only) Set the attribute for a file (%attr), e.g. --rpm-attr 750,user1,group1:/some/file
* ``--rpm-init FILEPATH``
	- (rpm only) Add FILEPATH as an init script
* ``--rpm-filter-from-provides REGEX``
	- (rpm only) Set %filter_from_provides to the supplied REGEX.
* ``--rpm-filter-from-requires REGEX``
	- (rpm only) Set %filter_from_requires to the supplied REGEX.
* ``--rpm-tag TAG``
	- (rpm only) Adds a custom tag in the spec file as is. Example: --rpm-tag 'Requires(post): /usr/sbin/alternatives'
* ``--[no-]rpm-ignore-iteration-in``
	- -dependencies (rpm only) For '=' (equal) dependencies, allow iterations on the specified version. Default is to be specific. This option allows the same version of a package but any iteration is permitted
* ``--[no-]rpm-verbatim-gem-depend``
	- encies (rpm only) When converting from a gem, leave the old (FPM 0.4.x) style dependency names. This flag will use the old 'rubygem-foo' names in rpm requires instead of the redhat style rubygem(foo). (default: false)
* ``--[no-]rpm-macro-expansion``
	- (rpm only) install-time macro expansion in %pre %post %preun %postun scripts (see: https://rpm.org/user_doc/scriptlet_expansion.html) (default: false)
* ``--rpm-verifyscript FILE``
	- (rpm only) a script to be run on verification
* ``--rpm-pretrans FILE``
	- (rpm only) pretrans script
* ``--rpm-posttrans FILE``
	- (rpm only) posttrans script
* ``--rpm-trigger-before-install '[OPT]PACKAGE: FILEPATH'``
	- (rpm only) Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--rpm-trigger-after-install '[OPT]PACKAGE: FILEPATH'``
	- (rpm only) Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--rpm-trigger-before-uninstall '[OPT]PACKAGE: FILEPATH'``
	- (rpm only) Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--rpm-trigger-after-target-uninstall '[OPT]PACKAGE: FILEPATH'``
	- (rpm only) Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--cpan-perl-bin PERL_EXECUTABLE``
	- (cpan only) The path to the perl executable you wish to run. (default: "perl")
* ``--cpan-cpanm-bin CPANM_EXECUTABLE``
	- (cpan only) The path to the cpanm executable you wish to run. (default: "cpanm")
* ``--cpan-mirror CPAN_MIRROR``
	- (cpan only) The CPAN mirror to use instead of the default.
* ``--[no-]cpan-mirror-only``
	- (cpan only) Only use the specified mirror for metadata. (default: false)
* ``--cpan-package-name-prefix NAME_PREFIX``
	- (cpan only) Name to prefix the package name with. (default: "perl")
* ``--[no-]cpan-test``
	- (cpan only) Run the tests before packaging? (default: true)
* ``--[no-]cpan-verbose``
	- (cpan only) Produce verbose output from cpanm? (default: false)
* ``--cpan-perl-lib-path PERL_LIB_PATH``
	- (cpan only) Path of target Perl Libraries
* ``--[no-]cpan-sandbox-non-core  ``
	- (cpan only) Sandbox all non-core modules, even if they're already installed (default: true)
* ``--[no-]cpan-cpanm-force``
	- (cpan only) Pass the --force parameter to cpanm (default: false)
* ``--pear-package-name-prefix PREFIX``
	- (pear only) Name prefix for pear package (default: "php-pear")
* ``--pear-channel CHANNEL_URL``
	- (pear only) The pear channel url to use instead of the default.
* ``--[no-]pear-channel-update``
	- (pear only) call 'pear channel-update' prior to installation
* ``--pear-bin-dir BIN_DIR``
	- (pear only) Directory to put binaries in
* ``--pear-php-bin PHP_BIN``
	- (pear only) Specify php executable path if differs from the os used for packaging
* ``--pear-php-dir PHP_DIR``
	- (pear only) Specify php dir relative to prefix if differs from pear default (pear/php)
* ``--pear-data-dir DATA_DIR``
	- (pear only) Specify php dir relative to prefix if differs from pear default (pear/data)
* ``--python-bin PYTHON_EXECUTABLE``
	- (python only) The path to the python executable you wish to run. (default: "python")
* ``--python-easyinstall EASYINSTALL_EXECUTABLE``
	- (python only) The path to the easy_install executable tool (default: "easy_install")
* ``--python-pip PIP_EXECUTABLE``
	- (python only) The path to the pip executable tool. If not specified, easy_install is used instead (default: nil)
* ``--python-pypi PYPI_URL``
	- (python only) PyPi Server uri for retrieving packages. (default: "https://pypi.python.org/simple")
* ``--python-trusted-host PYPI_TRUSTED``
	- (python only) Mark this host or host:port pair as trusted for pip (default: nil)
* ``--python-package-name-prefix PREFIX``
	- (python only) Name to prefix the package name with. (default: "python")
* ``--[no-]python-fix-name``
	- (python only) Should the target package name be prefixed? (default: true)
* ``--[no-]python-fix-dependencies``
	- (python only) Should the package dependencies be prefixed? (default: true)
* ``--[no-]python-downcase-name``
	- (python only) Should the target package name be in lowercase? (default: true)
* ``--[no-]python-downcase-dependencies``
	- (python only) Should the package dependencies be in lowercase? (default: true)
* ``--python-install-bin BIN_PATH ``
	- (python only) The path to where python scripts should be installed to.
* ``--python-install-lib LIB_PATH ``
	- (python only) The path to where python libs should be installed to (default depends on your python installation). Want to find out what your target platform is using? Run this: python -c 'from distutils.sysconfig import get_python_lib; print get_python_lib()'
* ``--python-install-data DATA_PATH``
	- (python only) The path to where data should be installed to. This is equivalent to 'python setup.py --install-data DATA_PATH
* ``--[no-]python-dependencies``
	- (python only) Include requirements defined in setup.py as dependencies. (default: true)
* ``--[no-]python-obey-requirements-txt``
	- (python only) Use a requirements.txt file in the top-level directory of the python package for dependency detection. (default: false)
* ``--python-scripts-executable PYTHON_EXECUTABLE``
	- (python only) Set custom python interpreter in installing scripts. By default distutils will replace python interpreter in installing scripts (specified by shebang) with current python interpreter (sys.executable). This option is equivalent to appending 'build_scripts --executable PYTHON_EXECUTABLE' arguments to 'setup.py install' command.
* ``--python-disable-dependency PACKAGE_NAME``
	- (python only) The python package name to remove from dependency list (default: [])
* ``--python-setup-py-arguments SETUP_PY_ARGUMENT``
	- (python only) Arbitrary argument(s) to be passed to setup.py (default: [])
* ``--osxpkg-identifier-prefix IDENTIFIER_PREFIX``
	- (osxpkg only) Reverse domain prefix prepended to package identifier, ie. 'org.great.my'. If this is omitted, the identifer will be the package name.
* ``--[no-]osxpkg-payload-free``
	- (osxpkg only) Define no payload, assumes use of script options. (default: false)
* ``--osxpkg-ownership OWNERSHIP  ``
	- (osxpkg only) --ownership option passed to pkgbuild. Defaults to 'recommended'. See pkgbuild(1). (default: "recommended")
* ``--osxpkg-postinstall-action POSTINSTALL_ACTION``
	- (osxpkg only) Post-install action provided in package metadata. Optionally one of 'logout', 'restart', 'shutdown'.
* ``--osxpkg-dont-obsolete DONT_OBSOLETE_PATH``
	- (osxpkg only) A file path for which to 'dont-obsolete' in the built PackageInfo. Can be specified multiple times.
* ``--solaris-user USER``
	- (solaris only) Set the user to USER in the prototype files. (default: "root")
* ``--solaris-group GROUP``
	- (solaris only) Set the group to GROUP in the prototype file. (default: "root")
* ``--p5p-user USER``
	- (p5p only) Set the user to USER in the prototype files. (default: "root")
* ``--p5p-group GROUP``
	- (p5p only) Set the group to GROUP in the prototype file. (default: "root")
* ``--p5p-zonetype ZONETYPE``
	- (p5p only) Set the allowed zone types (global, nonglobal, both) (default: "value=global value=nonglobal")
* ``--p5p-publisher PUBLISHER``
	- (p5p only) Set the publisher name for the repository (default: "FPM")
* ``--[no-]p5p-lint``
	- (p5p only) Check manifest with pkglint (default: true)
* ``--[no-]p5p-validate``
	- (p5p only) Validate with pkg install (default: true)
* ``--freebsd-origin ABI``
	- (freebsd only) Sets the FreeBSD 'origin' pkg field (default: "FPM/<name>")
* ``--snap-yaml FILEPATH``
	- (snap only) Custom version of the snap.yaml file.
* ``--snap-confinement CONFINEMENT``
	- (snap only) Type of confinement to use for this snap. (default: "devmode")
* ``--snap-grade GRADE``
	- (snap only) Grade of this snap. (default: "devel")
* ``--pacman-optional-depends PACKAGE``
	- (pacman only) Add an optional dependency to the pacman package.
* ``--[no-]pacman-use-file-permissions``
	- (pacman only) Use existing file permissions when defining ownership and modes
* ``--pacman-user USER``
	- (pacman only) The owner of files in this package (default: "root")
* ``--pacman-group GROUP``
	- (pacman only) The group owner of files in this package (default: "root")
* ``--pacman-compression COMPRESSION``
	- (pacman only) The compression type to use, must be one of gz, bzip2, xz, zstd, none. (default: "zstd")
* ``--pleaserun-name SERVICE_NAME ``
	- (pleaserun only) The name of the service you are creating
* ``--pleaserun-chdir CHDIR``
	- (pleaserun only) The working directory used by the service
* ``--virtualenv-pypi PYPI_URL``
	- (virtualenv only) PyPi Server uri for retrieving packages. (default: "https://pypi.python.org/simple")
* ``--virtualenv-package-name-prefix PREFIX``
	- (virtualenv only) Name to prefix the package name with. (default: "virtualenv")
* ``--[no-]virtualenv-fix-name``
	- (virtualenv only) Should the target package name be prefixed? (default: true)
* ``--virtualenv-other-files-dir DIRECTORY``
	- (virtualenv only) Optionally, the contents of the specified directory may be added to the package. This is useful if the virtualenv needs configuration files, etc. (default: nil)
* ``--virtualenv-pypi-extra-url PYPI_EXTRA_URL``
	- (virtualenv only) PyPi extra-index-url for pointing to your priviate PyPi (default: nil)
* ``--[no-]virtualenv-setup-install``
	- (virtualenv only) After building virtualenv run setup.py install useful when building a virtualenv for packages and including their requirements from 
* ``--[no-]virtualenv-system-site-packages``
	- (virtualenv only) Give the virtual environment access to the global site-packages
* ``--virtualenv-find-links PIP_FIND_LINKS``
	- (virtualenv only) If a url or path to an html file, then parse for links to archives. If a local path or file:// url that's a directory, then look for archives in the directory listing. (default: nil)
