Release Notes and Change Log
============================

1.14.2 (March 30, 2022)
^^^^^^^^^^^^^^^^^^^^^^^
* deb: fix bug causing ``--deb-compression none`` to invoke ``tar`` incorrectly (`#1879`_; John Howard)
* rpm: Better support for paths that have spaces and mixed quotation marks in them. (`#1882`_, `#1886`_, `#1385`_; John Bollinger and Jordan Sissel)
* pacman: Fix typo preventing the use of ``--pacman-compression xz`` (`#1876`_; mszprejda)
* docs: All supported package types now have dedicated documentation pages. Some pages are small stubs and would benefit from future improvement. (`#1884`_; mcandre, Jordan Sissel)
* docs: Small but lovely documentation fixes (`#1875`_ by Corey Quinn, `#1864`_ by Geoff Beier)
* Fixed mistake causing the test suite to fail when ``rake`` wasn't available. (`#1877`_; Jordan Sissel)

1.14.1 (November 10, 2021)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* Fix a bug that impacted fpm api usage (from other ruby programs) that caused an error "NameError: uninitialized constant FPM::Package::CPAN" when trying to output a Deb package. (`#1854`_, `#1856`_; Karol Bucek, Jordan Sissel)

1.14.0 (November 9, 2021)
^^^^^^^^^^^^^^^^^^^^^^^^^
* python: Use pip by default for fetching Python packages. This matches the Python 3 "installation" docs which recommend calling pip as ``python -m pip`` where ``python`` depends on ``--python-bin`` (default "python"). Previous default was to use `easy_install` which is no longer available on many newer systems. To use easy_install, you can set ``--no-python-internal-pip`` to revert this pip default. Further, you can specify your own pip path instead of using ``python -m pip`` with the ``--python-pip /path/to/pip`` flag. (`#1820`_, `#1821`_; Jordan Sissel)
* python: Support extras_require build markers in python packages (`#1307`_, `#1816`_; Joris Vandermeersch)
* freebsd: Fix bug which caused fpm to generate incorrect FreeBSD packages "missing leading `/`" (`#1811`_, `#1812`_, `#1844`_, `#1832`_, `#1845`_; Vlastimil Holer, Clayton Wong, Markus Ueberall, Jordan Sissel)
* deb: In order to only allow fpm to create valid packages, fpm now rejects packages with invalid "provides" (``--provides``) values. (`#1829`_, `#1825`_; Jordan Sissel, Peter Teichman)
* deb: Only show a warning about /etc and config files if there are files in /etc (`#1852`_, `#1851`_; Jordan Sissel)

* rpm: replace dash with underscore in rpm's "Release" field aka what fpm calls ``--iteration``. (`#1834`_, `#1833`_; Jordan Sissel)
* empty: `fpm -s empty ...` now defaults to "all" architecture instead of "native". (`#1850`_, `#1846`_; Jordan Sissel)
* Significant documentation improvements rewriting most of the documentation. New overview pages, full CLI flag listing, and new sections dedicated package types (rpm, cpan, deb, etc). (`#1815`_, `#1817`_, `#1838`_; Vedant K, Jordan Sissel)
* Typo fixes in documentation are always appreciated! (`#1842`_; Clayton Wong)
* fpm can now (we hope!) now be tested more easily from docker (`#1818`_, `#1682`_, `#1453`_; @directionless, Jordan Sissel, Douglas Muth)

1.13.1 (July 6, 2021)
^^^^^^^^^^^^^^^^^^^^^
* deb: The `--provides` flag now allows for versions. Previously, fpm would
  remove the version part of a provides field when generating deb packages.
  (`#1788`_, `#1803`_; Jordan Sissel, Phil Schwartz, tympanix)
* osxpkg: Update documentation to include installing `rpm` tools on OSX
  (`#1797`_; allen joslin)

1.13.0 (June 19, 2021)
^^^^^^^^^^^^^^^^^^^^^^
* Apple M1 users should now work (`#1772`_, `#1785`_, `#1786`_; Jordan Sissel)
* Removed `ffi` ruby library as a dependency. This should make it easier to support a wider range of Ruby versions (Ruby 2.2, 3.0, etc) and platforms (like arm64, Apple M1, etc) in the future. (`#1785`_, `#1786`_; Jordan Sissel)
* Now uses the correct architecture synonym for ARM 64 systems. Debian uses `arm64` as a synonym for what other systems call `aarch64` (linux kernel, RPM, Arch Linux). (`#1775`_; Steve Kamerman)
* Docs: Fix a typo in an example (`#1785`_; Zoe O'Connell)
* rpm: File paths can now contain single-quote characters (`#1774`_; Jordan Sissel)
* rpm: Use correct SPEC syntax when using --after-upgrade or similar features (`#1761`_; Jo Vandeginste. Robert Fielding)
* Ruby 3.0 support: Added `rexml` as a runtime dependency. In Ruby 2.0, `rexml` came by default, but in Ruby 3.0, `rexml` is now a bundled gem and some distributiosn do not include it by default. (`#1794`_; Jordan Sissel)
* Fix error "git: not found (Git::GitExecuteError)". Now loads `git` library only when using git features. (`#1753`_, `#1748`_, `#1751`_, `#1766`_; Jordan Sissel, Cameron Nemo, Jason Rogers, Luke Short)
* deb: Fix syntax error in `postinst` (`--after-install`) script. (`#1752`_, `#1749`_, `#1764`_; rmanus, Adam Mohammed, Elliot Murphy, kimw, Jordan Sissel)
* deb: --deb-compression now uses the same compression and file suffix on the control.tar file (`#1760`_; Philippe Poilbarbe)


1.12.0 (January 19, 2021)
^^^^^^^^^^^^^^^^^^^^^^^^^

* Pin ffi dependency to ruby ffi 1.12.x to try keeping fpm compatible with older/abandoned rubies like 2.0 and 2.1. (`#1709`_; Matt Patterson)
* deb: New flag to add 'set -e' to all scripts. `--deb-maintainerscripts-force-errorchecks` which defaults to off. (`#1697`_; Andreas Ulm)
* deb: Fix bug when converting rubygems to debs where certain constraints like `~>1` would generate a deb dependency that couldn't be satisfied. (`#1699`_; Vlastimil Holer)
* deb: Fix error 'uninitialized constant FPM::Package::Deb::Zlib' (`#1739`_, `#1740`_; Federico Lancerin)
* python: Prepend to PYTHONPATH instead of replacing it. This should help on platforms that rely heavily on PYTHONPATH, such as NixOSX (`#1711`_, `#1710`_; anarg)
* python: Add `--python-trusted-host` flag which passes `--trusted-host` flag to `pip` (`#1737`_; Vladimir Ponarevsky)
* Documentation improvements (`#1724`_, `#1738`_, `#1667`_, `#1636`_)
* Dockerfile updated to Alpine 3.12 (`#1745`_; Cameron Nemo)
* Remove the 'backports' deprecation warning (`#1727`_; Jose Galvez)
* sh: Performance improvement when printing package metadata (`#1729`_; James Logsdon, Ed Healy)
* rpm: Add support for `xzmt` compression (multithreaded xz compressor) to help when creating very large packages (several gigabytes). (`#1447`_, `#1419`_; amnobc)
* rpm: Add `--rpm-macro-expansion` flag to enable macro expansion in scripts during rpmbuild. See https://rpm.org/user_doc/scriptlet_expansion.html for more details. (`#1642`_; juliantrzeciak)
* deb: use correct control.tar filename (`#1668`_; Mike Perham)

1.11.0 (January 30, 2019)
^^^^^^^^^^^^^^^^^^^^^^^^^

* snap: Snap packages can now be created! (`#1490`_; kyrofa)
* Fix an installation problem where a dependency (childprocess) fails to install correctly. (#1592; Jordan Sissel)

1.10.2 (July 3, 2018)
^^^^^^^^^^^^^^^^^^^^^

* cpan: Fix a crash where fpm would crash trying to parse a perl version string (`#1515`_, `#1514`; Jordan Sissel, William N. Braswell, Jr)

1.10.1 (July 3, 2018)
^^^^^^^^^^^^^^^^^^^^^

* cpan: Fixes some package building by setting PERL5LIB correctly (`#1509`_, `#1511`_; William N. Braswell, Jr)
* cpan: Adds `--[no-]cpan-verbose` flag which, when set, runs `cpanm` with the `--verbose` flag (`#1511`_; William N. Braswell, Jr)

1.10.0 (May 21, 2018)
^^^^^^^^^^^^^^^^^^^^^

* Pin `ruby-xz` dependency to one which allows Ruby versions older than 2.3.0 (`#1494`_; Marat Sharafutdinov)
* Documentation improvements: `#1488`_; Arthur Burkart. `#1384`_; Justin Kolberg. `#1452`_; Anatoli Babenia.
* python: Improve support for the `~=` dependency comparison. (`#1482`_; Roman Vasilyev)
* deb: Add `--deb-generate-changes` flag to have fpm output a `.changes` file (`#1492`_; Spida)
* deb: Add `--deb-dist` flag to set the target distribution (similar to `--rpm-dist`). (`#1492`_; Spida)
* apk: Make --before-install, --before-upgrade, and --after-upgrade work correctly. (`#1422`_; Charles R. Portwood II)
* rpm: add `xzmt` for multithreaded xz compression (Amnon BC)
* rpm: fix shell function name `install` conflicting with `install` program. In
  postinst (after-install), the function is now called `_install` to avoid
  conflicting with `/usr/bin/install` (`#1434`_; Torsten Schmidt)
* rpm: Allow binary "arch dependent" files in noarch rpms (Jordan Sissel)
* - deb: --config-files ? (`#1440`_, `#1443`_; NoBodyCam)
* FPM source repo now contains a Brewfile for use with Homebrew.
* FPM source repo has a Dockerfile for invoking fpm with docker. (`#1484`_, ;Allan Lewis

1.9.3 (September 11, 2017)
^^^^^^^^^^^^^^^^^^^^^^^^^^

* fix a bug when coyping a symlink using path mapping would result in the link creating a directory to hold think. (`#1395`_; Nemanja Boric)

1.9.2 (July 29, 2017)
^^^^^^^^^^^^^^^^^^^^^

* rpm: Fix `--config-files` handling (`#1390`_, `#1391`_; Jordan Sissel)

1.9.1 (July 28, 2017) happy sysadmin day!
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* Documentation improvements: `#1291`_; Pablo Castellano. `#1321`_; ge-fa. `#1309`_; jesusbagpuss. `#1349`_; Perry Stole. `#1352`_, Jordan Sissel. `#1384`_; Justin Kolberg.
* Testing improvements: `#1320`_; Rob Young. `#1266`_; Ryan Parman. `#1374`_; Thiago Figueiró.
* Fix bug so fpm can now copy symlinks correctly (`#1348`_; ServiusHack)
* apk: Improve performance (`#1358`_; Jan Delgado)
* cpan: Fix crash when CPAN query returns a version value that was a number and fpm was expecting a string. (`#1344`_, `#1343`_; liger1978)
* cpan: Fix MetaCPAN searches to use v1 of MetaCPAN's API. The v0 API is no longer provided by MetaCPAN. (`#1341`_, `#1339`_; Bob Bell)
* cpan: Have perl modules implicitly "provide" (`--provides`) capabilities. (`#1340`_; Bob Bell. `#1345`_; liger1978)
* cpan: Now transforms perl version values like "5.008001" to "5.8.1" (`#1342`_; Bob Bell)
* cpan: Use `>=` ("this version or newer") for package dependencies instead of `=` ("exactly this version"). (`#1338`_; Bob Bell)
* deb: Add `--deb-after-purge` flag for running a script after `apt-get purge` is run. (Alexander Weidinger)
* deb: fix bug when using `--deb-upstart` would use the wrong file name (`#1325`_, `#1287`_; vbakayev)
* deb: New flags `--deb-interest-noawait` and `--deb-activate-nowait`. (`#1225`_, `#1359`_; Philippe Poilbarbe)
* dir: Remove a debug statement that would put fpm into a debug prompt (`#1293`_, `#1259`_; Joseph Anthony Pasquale Holsten)
* dir: When using `path mapping`_ (`a=b` syntax), and `a` is a symlink, use the path `b` as the symlink, not `b/a` (`#1253`_, Nemanja Boric)
* gem: Can now make reproducible_builds_ when building a deb (`-s gem -t deb`). See the `Deterministic output`_ docs.
* gem: Add `--gem-embed-dependencies` flag to include in the output package all dependent gems of the target. For example, `fpm -s gem -t rpm --gem-embed-dependencies rails` will create a single `rails` rpm that includes active_support, active_record, etc.
* pleaserun: Add more flags (`--pleaserun-chdir`, `--pleaserun-user`, etc) to allow more customization of pleaserun services. (`#1311`_; Paulo Sousa)
* python: Add `--python-setup-py-arguments` flag for passing arbitrary flags to `python setup.py install` (`#1120`_, `#1376`_; Ward Vandewege, Joseph Anthony Pasquale Holsten)
* rpm: --config-files can now copy files from outside of the package source. This means you can do things like `fpm -s gem -t rpm --config-files etc/my/config` and have `etc/my/config` come from the local filesystem. (`#860`_, `#1379`_; jakerobinson, Joseph Anthony Pasquale Holsten)
* tar: Only create `.scripts` directory if there are scripts to include (`#1123`_, `#1374`_; Thiago Figueiró)
* virtualenv: Add `--virtualenv-find-links` flag which appends `--find-links` to the `pip install` command.
* virtualenv: documentation improvements (Nick Griffiths)
* virtualenv: Make `--prefix` useful and deprecate `--virtualenv-install-location` (`#1262`_; Nick Griffiths)
* zip: fix bug in output where the temporary directory would be included in the file listing (`#1313`_, `#1314`_; Bob Vincent)
* Other: Remove unused archive-tar-minitar as a dependency of fpm (`#1355`_; Diego Martins)
* Other: Add stud as a runtime dependency (`#1354`_; Elan Ruusamäe)

.. _reproducible_builds: https://reproducible-builds.org/
.. _path mapping: source/dir.html#path-mapping
.. _Deterministic output: source/gem.html

1.9.0 (July 28, 2017)
^^^^^^^^^^^^^^^^^^^^^

Yanked offline. I forgot some dependency changes. Hi.

1.8.1 (February 7, 2017)
^^^^^^^^^^^^^^^^^^^^^^^^
* Pin archive-tar-minitar library to version 0.5.2 to work around a problem breaking `gem install fpm`

1.8.0 (December 28, 2016)
^^^^^^^^^^^^^^^^^^^^^^^^^
* virtualenv: Add `--virtualenv-setup-install` flag to run `setup.py install` after pip finishes installing things. (`#1218`_; John Stowers)
* virtualenv: Add `--virtualenv-system-site-package` flag which creates the virtualenv in a way that allows it to use the system python packages. (`#1218`_; John Stowers)
* cpan: Fix bug preventing some perl modules from being installed (`#1236`_, `#1241`_; Richard Grainger)
* rpm: Documentation improvements (`#1242`_; Nick Griffiths)

1.7.0 (November 28, 2016)
^^^^^^^^^^^^^^^^^^^^^^^^^
* virtualenv: Fix a bug where `pip` might be run incorrectly (`#1210`_; Nico Griffiths)
* FreeBSD: --architecture (-a) flag now sets FreeBSD package ABI (`#1196`_; Matt Sharpe)
* perl/cpan: Fix bug and now local modules can be packaged (`#1202`_, `#1203`_; liger1978)
* perl/cpan: Add support for `http_proxy` environment variable and improve how fpm queries CPAN for package information. (`#1206`_, `#1208`_; liger1978)
* Fix crash for some users (`#1231`_, `#1148`_; Jose Diaz-Gonzalez) 
* Documentation now published on fpm.readthedocs.io. This is a work-in progress. Contributions welcome! <3 (`#1237`_, Jordan Sissel)
* deb: Can now read bz2-compressed debian packages. (`#1213`_; shalq)
* pleaserun: New flag --pleaserun-chdir for setting the working directory of a service. (`#1235`_; Claus F. Strasburger)

1.6.3 (September 15, 2016)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* Fix bug in fpm's release that accidentally included a few `.pyc` files (`#1191`_)

1.6.2 (July 1, 2016)
^^^^^^^^^^^^^^^^^^^^
* Reduce `json` dependency version to avoid requiring Ruby 2.0 (`#1146`_, `#1147`_; patch by Matt Hoffman)
* pacman: skip automatic dependencies if --no-auto-depends is given (Leo P)
* rpm: Fix bug where --rpm-tag was accidentally ignored (`#1134`_, Michal Mach)
* deb: Omit certain fields from control file if (Breaks, Depends, Recommends, etc) if there are no values to put in that field. (`#1113`_, TomyLobo)
* rpm: remove trailing slash from Prefix for rpm packages (`#819`_, luto)
* virtualenv: Now supports being given a requirements.txt as the input. (Nick Griffiths)

1.6.1 (June 10, 2016)
^^^^^^^^^^^^^^^^^^^^^
* freebsd: Only load xz support if we are doing a freebsd output. (`#1132`_, `#1090`_, Ketan Padegaonkar)

1.6.0 (May 25, 2016)
^^^^^^^^^^^^^^^^^^^^
* New source: pleaserun. This lets you create packages that will install a system service. An after-install script is used in the package to determine which service platform to target (systemd, upstart, etc). Originated from Aaron Mildenstein's work on solving this problem for Logstash. (`#1119`_, `#1112`_)
* New target: Alpine Linux "apk" packages. (`#1054`_, George Lester)
* deb: don't append `.conf` to an upstart file if the file name already ends in `.conf`. (`#1115`_, josegonzalez)
* freebsd: fix bug where --package flag was ignored. (`#1093`_, Paweł Tomulik)
* Improvements to the fpm rake tasks (`#1101`_, Evan Gilman)
  
1.5.0 (April 12, 2016)
^^^^^^^^^^^^^^^^^^^^^^
* Arch package support is now available via -s pacman and -t pacman.  (`#916`_; wonderful community effort making this happen!)
* FreeBSD packages can now be built `-t freebsd` (`#1073`_; huge community effort making this happen!)
* You can now set fpm flags and arguments with the FPMOPTS environment variable (`#977`_, mildred)
* Using --exclude-file no longer causes a crash. Yay! (`#982`_, wyaeld)
* A new rake task is available for folks who want to invoke fpm from rake (`#756`_, pstengel)
* On FreeBSD, when tarring, gtar is now used. (`#1008`_, liv3d)
* virtualenv: Add --virtualenv-pypi-extra-url flag to specify additional PyPI locations to use when searching for packages (`#1012`_, Paul Krohn)
* deb: Init scripts, etc/default, and upstart files are automatically added as config files in a debian package. Disable this behavior with ---deb-auto-config-files
* deb: Small changes to make lintian complain less about our resulting debs.
* deb: New flag --deb-systemd lets you specify a systemd service file to include in your package. (`#952`_, Jens Peter Schroer)
* cpan: Add --[no-]cpan-cpanm-force flag to pass --force to cpanm.
* rpm: File names with both spaces and symbols should now be packageable.  (`#946`_, iwonbigbro)
* cpan: Now queries MetaCPAN for package info if we can't find any in the cpan archive we just downloaded. (`#849`_, BaxterStockman)
* rpm: You can now specify custom rpm tags at the command line. Be careful, as no validation is done on this before sending to rpmbuild. (`#687`_, vStone)
* cpan: Install if the package name given is a local file (`#986`_, mdom)
* sh: Metadata now available as env vars for post-install scripts (`#1006`_, Ed Healy)
* rpm: No more warning if you don't set an epoch. (`#1053`_, Joseph Frazier)


1.4.0 (July 26, 2015)
^^^^^^^^^^^^^^^^^^^^^
* Solaris 11 IPS packages 'p5p' now supported `-t p5p`. (Jonathan Craig)
* Python Virtualenv is now supported `-t virtualenv` (`#930`_, Simone Margaritelli and Daniel Haskin)
* deb: Files in /etc are now by default marked as config files. (`#877`_, Vincent Bernat)
* `fpm --help` output now includes a list of supported package types (`#896`_, Daniel Haskin)
* cpan: --[no-]cpan-sandbox-non-core flag to make non-core module sandboxing optional during packaging (`#752`_, Matt Sharpe)
* rpm: Add --rpm-dist flag for specifically setting the target distribution of an rpm.  (Adam Lamar)
* rpm: Fix a crash if --before-upgrade or --after-upgrade were used. (`#822`_, Dave Anderson)
* deb: Ensure maintainer scripts have shebang lines (`#836`_, Wesley Spikes)
* deb: Fix bug in maintainer scripts where sometimes we would write an empty shell function. Empty functions aren't valid in shell. (Wesley Spikes)
* Fix symlink copying bug (`#863`_, Pete Fritchman)
* python: Default to https for pypi queries (Timothy Sutton)
* New flag --exclude-file for providing a file containing line-delimited exclusions (Jamie Lawrence)
* python: new flag --python-disable-dependency to disable specific python dependencies (Ward Vandewege)
* python: ensure we avoid wheel packages for now until fpm better supports them.  (`#885`_, Matt Callaway)
* deb: Add support for installation states "abort-remove" and "abort-install" (`#887`_, Daniel Haskin)
* If PATH isn't set, and we need it, tell the user (`#886`_, Ranjib Dey)
* cpan: --[no-]cpan-test now works correctly (`#853`_, Matt Schreiber)
* deb-to-rpm: some improved support for config file knowledge passing from deb to rpm packages (Daniel Haskin)
    
1.3.3 (December 11, 2014)
^^^^^^^^^^^^^^^^^^^^^^^^^
* The fpm project now uses Contributor Covenant. You can read more about this on the website: http://contributor-covenant.org/
* npm: Fix bug causing all `-s npm` attempts to fail due to a missing method.  This bug was introduced in 1.3.0. (`#800`_, `#806`_; Jordan Sissel)
* rpm: fix bug in rpm input causing a crash if the input rpm did not have any triggers (`#801`_, `#802`_; Ted Elwartowski)

1.3.2 (November 4, 2014)
^^^^^^^^^^^^^^^^^^^^^^^^
* deb: conversion from another deb will automatically use any changelog found in the source deb (Jordan Sissel)

1.3.1 (November 4, 2014)
^^^^^^^^^^^^^^^^^^^^^^^^
* deb: fix md5sums generation such that `dpkg -V` now works (`#799`_, Matteo Panella)
* rpm: Use maximum compression when choosing xz (`#797`_, Ashish Kulkarni)
  
1.3.0 (October 25, 2014)
^^^^^^^^^^^^^^^^^^^^^^^^
* Fixed a bunch of Ruby 1.8.7-related bugs. (Jordan Sissel)
* cpan: Fix bug in author handling (`#744`_, Leon Weidauer)
* cpan: Better removal of perllocal.pod (`#763`_, `#443`_, `#510`_, Mathias Lafeldt)
* rpm: Use lstat calls instead of stat, so we don't follow symlinks (`#765`_, Shrijeet Paliwal)
* rpm and deb: Now supports script actions on upgrades. This adds two new flags: --before-upgrade and --after-upgrade. (`#772`_, `#661`_; Daniel Haskin)
* rpm: Package triggers are now supported. New flags: --rpm-trigger-before-install, --rpm-trigger-after-install, --rpm-trigger-before-uninstall, --rpm-trigger-after-target-uninstall. (`#626`_, Maxime Caumartin)
* rpm: Add --rpm-init flag; similar to --deb-init. (Josh Dolitsky)
* sh: Skip installation if already installed for the given version. If forced, the old installation is renamed. (`#776`_, Chris Gerber)
* deb: Allow Vendor field to be omitted now by specifying `--vendor ""` (`#778`_, Nate Brown)
* general: Add --log=level flag for setting log level. Levels are error, warn, info, debug. (Jordan SIssel)
* cpan: Check for Build.PL first before Makefile.PL (`#787`_, Daniel Jay Haskin)
* dir: Don't follow symlinks when copying files (`#658`_, Jordan Sissel)
* deb: Automatically provide a 'changes' file in debs because lintian complains if they are missing. (`#784`_, Jordan Sissel)
* deb: Fix and warn for package names that have spaces (`#779`_, Grantlyk)
* npm: Automatically set the prefix to `npm prefix -g` (`#758`_, Brady Wetherington and Jordan Sissel)

1.2.0 (July 25, 2014)
^^^^^^^^^^^^^^^^^^^^^
* rpm: Add --rpm-verifyscript for adding a custom rpm verify script to your package. (Remi Hakim)
* Allow the -p flag to target a directory for writing the output package (`#656`_, Jordan Sissel)
* Add --debug-workspace which skips any workspace cleanup to let users debug things if they break. (`#720`_, `#734`_; Jordan Sissel)
* rpm: Add --rpm-attr for controlling attribute settings per file. This setting will likely be removed in the future once rpmbuild is no longer needed.  (`#719`_)
* deb: Add --deb-meta-file to add arbitrary files to the control dir (`#599`_, Dan Brown)
* deb: Add --deb-interest and --deb-activate for adding package triggers (`#595`_, Dan Brown)
* cpan: Fix small bug in handling empty metadata fields (`#712`_, Mathias Lafeldt)
* rpm: Fix bug when specifying both --architecture and --rpm-os (`#707`_, `#716`_; Alan Ivey)
* gem: Fix bug where --gem-version-bins is given but package has no bins (`#688`_, Jan Vansteenkiste)
* deb: Set permissions correct on the package's internals. Makes lintian happier. (Jan Vansteenkiste)
* rpm: rpmbuild's _tmppath now respects --workdir (`#714`_, Jordan Sissel)
* gem/rpm: Add --rpm-verbatim-gem-dependencies to use old-style (fpm 0.4.x) rpm gem dependencies (`#724`_, Jordan Sissel)
* gem/rpm: Fix bug for gem pessimistic constraints when converting to rpm (Tom Duckering)
* python: Fix small bug with pip invocations (`#727`_, Dane Knecht)

1.1.0 (April 23, 2014)
^^^^^^^^^^^^^^^^^^^^^^
* New package type: zip, for converting to and from zip files (Jordan Sissel)
* New package type: sh, a self-extracting package installation shell archive. (`#651`_, Chris Gerber)
* 'fpm --version' will now emit the version of fpm.
* rpm: supports packaging fifo files (Adam Stephens)
* deb: Add --deb-use-file-permissions (Adam Stephens)
* cpan: Improve how fpm tries to find cpan artifacts for download (`#614`_, Tim Nicholas)
* gem: Add --gem-disable-dependency for removing one or more specific rubygem dependencies from the automatically-generated list (`#598`_, Derek Olsen)
* python: Add --python-scripts-executable for setting a custom interpreter to use for the hashbang line at the top of may python package scripts.  (`#628`_, Vladimir Rutsky)
* Allow absolute paths with --directories even when --prefix is used (Vladimir Rutsky)
* dir: Now correctly identifies hardlinked files and creates a package correctly with that knowledge (`#365`_, `#623`_, `#659`_; Vladimir Rutsky)
* rpm: Add --rpm-auto-add-exclude-directories for excluding directories from the --rpm-auto-add-directories behavior (`#640`_, Vladimir Rutsky)
* general: --config-files now accepts directories and will recursively mark any files within as config files inside the package (`#642`_, Vladimir Rutsky)
* general: If you specify a --config-files path that doesn't exist, you will now get an error. (`#654`_, Alan Franzoni)
* python: Support --python-pypi when using --python-pip (`#652`_, David Lindquist)
* deb: Tests now try to make packages ensure we don't upset lintian (`#648`_, Sam Crang)
* rpm: Fix architecture targeting (`#676`_, Rob Kinyon)
* rpm: Allow --rpm-user and --rpm-group to override the user/group even if --rpm-use-file-permissions is enabled. (`#679`_, Jordan Sissel)
* gem: Add --gem-version-bins for appending the gem version to the file name of executable scripts a rubygem may install. (Jan Vansteenkiste)
* python: Attempt to provide better error messages for known issues in python environments (`#664`_, Jordan Sissel)

1.0.2 (January 10, 2013)
^^^^^^^^^^^^^^^^^^^^^^^^
* rpm: No longer converts - to _ in dependency strings (`#603`_, Bulat Shakirzyanov)
* Handle Darwin/OSX tar invocations (now tries 'gnutar' and 'gtar'). (Jordan Sissel)
* Process $HOME/.fpm, and $PWD/.fpm in the correct order and allow CLI flags to override fpm config file settings. (`#615`_, Jordan Sissel)
* Don't leave empty gem bin paths in packages that don't need them (`#612`_, Jordan Sissel)
* deb: Make --deb-compression=gz work correctly (`#616`_, `#617`_; Evan Krall, Jason Yan)

1.0.1 (December 7, 2013)
^^^^^^^^^^^^^^^^^^^^^^^^
* deb: Correctly handle --config-files given with a leading / (Jordan Sissel)

1.0.0 (December 5, 2013)
^^^^^^^^^^^^^^^^^^^^^^^^
* Config file of flags is now supported. Searches for $HOME/.fpm and $PWD/.fpm. If both exist, $HOME is loaded first so $PWD can override.  (Pranay Kanwar)
* pkgin: Basic support for SmartOS/pkgsrc's pkgin format. (`#567`_, Brian Akins)
* cpan: catch more cases of perllocal.pod and delete them (`#510`_, Jordan Sissel)
* cpan: Correctly support module version selection (`#518`_, Matt Sharpe)
* cpan: include builddeps in PERL5LIB when running cpan tests (`#500`_, Matt Sharpe)
* cpan: Avoid old system perl modules when doing module builds (`#442`_, `#513`_; Matt Sharpe)
* python: safer gathering of python module dependencies.
* python: better handling of unicode strings in python package metadata (`#575`_, Bruno Renié)
* cpan: Support 'http_proxy' env var. (`#491`_, Patrick Cable)
* deb: --deb-user and --deb-group both default to 'root' now (`#504`_, Pranay Kanwar)
* deb: convert '>' to '>>' in deb version constraints (`#503`_, `#439`_, Pranay Kanwar)
* deb: Warn if epoch is set. Just so you know what's going on, since the default filename doesn't include the epoch. (`#502`_, Pranay Kanwar)
* deb,rpm: --config-files is now recursive if you give it a directory.  This seems to be the most expected behavior by users.  (`#171`_, `#506`_; Pranay Kanwar)
* dir: Respect -C when using path mapping (`#498`_, `#507`_; Pranay Kanwar)
* rpm: Add --rpm-ignore-iteration-in-dependencies to let you to depend on any release (aka iteration) of the same version of a package.  (`#364`_, `#508`_; Pranay Kanwar)
* dir: Handle copying of special files when possible (`#347`_, `#511`_, `#539`_, `#561`_; Pranay Kanwar)
* rpm: Don't mistake symlinks as actual directories (`#521`_, Nathan Huff)
* npm: Choose an alternate npm registry with --npm-registry (`#445`_, `#524`_; Matt Sharpe)
* cpan: Choose an alternate cpan server with --cpan-mirror. Additionally, you can use --cpan-mirror-only to only use this mirror for metadata queries.  (`#524`_, Matt Sharpe)
* deb: Fix broken --deb-changelog flag (`#543`_, `#544`_; Tray Torrance)
* deb: When --deb-upstart is given, automatically create an upstart-sysv symlink /etc/init.d/<name> to /lib/init/upstart-job (`#545`_, Igor Galić)
* rpm: Fix bug when generating spec file listings on files with strange characters in the names. (`#547`_, Chris Chandler)
* dir: Fix bug where the new directory mapping feature would cause you not to be able to select files with '=' in the name for packaging.  (`#556`_, `#554`_; Pranay Kanwar)
* python: Fix some unicode string issues in package metadata (`#575`_, Bruno Renié)
* gem-rpm: Now respects the --gem-package-name-prefix when generating the 'rubygem(name)' provides statement (`#585`_, Stepan Stipl)
* deb: Downcase and replace underscores with dashes in 'provides' list.  (`#591`_, Eric Connell)
* deb: Fix a lintian complaint about md5sums permissions (`#593`_, Sam Crang)
* cpan: Modules with 'MYMETA' files are now supported (`#573`_, Michael Donlon)

0.4.42 (July 23, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* dir: make source=destination mappings behave the same way 'rsync -a' does with respect to source and destination paths.

0.4.41 (July 17, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* cpan: handle cases where modules don't specify a license
* deb: support multiple init scripts (`#487`_, patch by Kristian Glass)

0.4.40 (July 12, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* dir: supports mapping one path to another. You set mappings by using 'source=destination' syntax. For example: % fpm -s dir -t deb -n example /home/jls/.zshrc=/etc/skel/ The key above is the '=' symbol. The result of the above will be a package containing only /etc/skel/.zshrc For more, see https://github.com/jordansissel/fpm/wiki/Source:-dir#mapping
* python: the default scripts location is now chosen by python itself. The previous default was "/usr/bin" and was not a good default. (`#480`_)
* rpm: config files should have attributes (`#484`_, patch by adamcstephens)
* python: correctly log the python setup.py exit code (`#481`_, patch by Derek Ludwig)

0.4.39 (June 27, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* cpan: support more complex dependency specifications (reported by Mabi Knittel)
  
0.4.38 (June 24, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* cpan: fpm's cpan code now works under ruby 1.8.7
* python: fix a bug in dependency handling (`#461`_, Pranay Kanwar)
* pear: Added --pear-data-dir flag (`#465`_, Zsolt Takács)
* cpan: fix a bug with some clean up on certain 64bit systems
* gem: improve detection of the gem bin install path (`#476`_, Tray Torrance)
* rpm: fix bug when calling using --rpm-use-file-permissions (`#464`_, Rich Horwood)

0.4.37 (May 30, 2013)
^^^^^^^^^^^^^^^^^^^^^
* deb: fix creation failures on OS X (`#450`_, patch by Anthony Scalisi and Matthew M. Boedicker)
* deb: you can now set --deb-build-depends. This is generally for extremely rare use cases. (`#451`_, patch by torrancew)
* perl: add --cpan-perl-lib-path for a custom perl library installation path (`#447`_, patch by Brett Gailey)

0.4.36 (May 15, 2013)
^^^^^^^^^^^^^^^^^^^^^
* pear: only do channel-discover if necessary (`#438`_, patch by Hatt)
* cpan: now supports cpan modules that use Module::Build
* cpan: --no-cpan-test now skips tests for build/configure dependencies
* rpm: Add --rpm-defattrfile and --rpm-defattrdir flags (`#428`_, patch by phrawzty)

0.4.35 -- was not announced 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

0.4.34 (May 7, 2013)
^^^^^^^^^^^^^^^^^^^^
* Now supports CPAN - Perl mongers rejoice! For example: 'fpm -s cpan -t deb DBI'
* deb: fixed some additional complaints by lintian (`#420`_, patch by Pranay Kanwar)
* rpm: add flags --rpm-autoreqprov, --rpm-autoreq, and --rpm-autoprov to tell rpm to enable that feature in the rpm spec. (`#416`_, patch by Adam Stephens)

0.4.33 (April 9, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* Now supports npm, the node package manager. For example: 'fpm -s npm -t deb express'

0.4.32 (April 9, 2013)
^^^^^^^^^^^^^^^^^^^^^^
* COMPATIBILITY WARNING: rpm: The default epoch is now nothing because this aligns more closely with typical rpm packages in the real world. This decision was reached in `#381`_. If you need the previous behavior, you must now specify '--epoch 1' (`#388`_, patch by Pranay Kanwar)
* python: new flag --python-obey-requirements-txt which makes a requirements.txt file from the python package used for the package dependencies instead of the usual setup.py dependencies. The default behavior without this flag is to respect setup.py. (`#384`_)
* deb: new flag --deb-shlibs to specify the content of the 'shlibs' file in the debian package (`#405`_, patch by Aman Gupta)
* deb: fixed a few lintian errors (empty conffiles, md5sums on symlinks, etc)
* Add '-f' / '--force' flag to force overwriting an existing package output path (`#385`_, Timothy Sutton)
* New flag: --no-auto-depends flag to skip any automatic dependencies that would normally be added by gem, python, deb, and rpms input packages.  (`#386`_, `#374`_; patch by Pranay Kanwar)
* gem: Use 'gem' command to download gems and read gem package information.  (`#389`_, `#394`_, `#378`_, `#233`_; patches by Pranay Kanwar and Chris Roberts)
* rpm: dashes are now replaced with underscores in rpm version strings (`#395`_, `#393`_, `#399`_;  patches by Jeff Terrace and Richard Guest)
* python: Only use the first line of a license; some python packages (like 'requests') embed their full license copy into the license field. For the sake of sanity and function with most packaging systems, fpm only uses the first line of that license.
* rpm: Add new 'none' option to --rpm-compression to disable compression entirely. (`#398`_, patch by Richard Guest)
* deb: Make dependencies using the '!=' operator represented as "Breaks" in the deb package (previously used "Conflicts"). (`#400`_)
* deb: Add md5sums to the debian packages which improves correctness of the package. (`#403`_, `#401`_; patch by Pranay Kanwar)
* rpm: Convert all '!=' dependency operators to 'Conflicts'. Previously, this only applied to packages converting from python to rpm.  (`#404`_, `#396`_; patch by Pranay Kanwar)

0.4.31 (March 21, 2013)
^^^^^^^^^^^^^^^^^^^^^^^
* rpm: new flag --rpm-use-file-permissions which try to create an rpm that has file ownership/modes that exactly mirror how they are on the filesystem at package time. (`#377`_, patch by Paul Rhodes)
* general: remove empty directories only when they match the exclude pattern (`#323`_, patch by Pranay Kanwar)

0.4.30 (March 21, 2013)
^^^^^^^^^^^^^^^^^^^^^^^
* Solaris: --solaris-user and --solaris-group flags to specify the owner of files in a package. (`#342`_, patch by Derek Olsen)
* rpm: (bug fix) epoch of 0 is permitted now (`#343`_, patch by Ben Hughes)
* pear: add flags --pear-bin-dir --pear-php-bin --pear-php-dir (`#358`_, patch by Zsolt Takács)
* New 'source' type: empty. Allows you to create packages without any files in them (sometimes called 'meta packages'). Useful when you want to have one package be simply dependencies or when you want to spoof a package you don't want installed, etc. (`#359`_, 349; patch by Pranay Kanwar)
* solaris: Add --solaris-user and --solaris-group flags (`#342`_, Patch by Derek Olsen)
* gem: new flag --env-shebang; default true (disable with --no-env-shebang).  Lets you disable #! (shebang) mangling done by gem installation. (`#363`_, patch by Grier Johnson)
* deb: fix bug on changelog handling (`#376`_, patch by mbakke)
* rpm: fix --rpm-rpmbuild-define (`#383`_, patch by Eric Merritt)

0.4.29 (January 22, 2013)
^^^^^^^^^^^^^^^^^^^^^^^^^
* Copy links literally, not what they point at (`#337`_, patch by Dane Knecht)

0.4.28 (January 21, 2013)
^^^^^^^^^^^^^^^^^^^^^^^^^
* Fix a dependency on the 'cabin' gem. (`#344`_, reported by Jay Buffington)

0.4.27 (January 16, 2013)
^^^^^^^^^^^^^^^^^^^^^^^^^
* Make all fpm output go through the logger (`#329`_; patch by jaybuff)
* New package type: osxpkg, for building packages installable on OS X. (`#332`_, patch by Timothy Sutton)
* Fix crash bug when converting rpms to something else (`#316`_, `#325`_; patch by rtucker-mozilla)
* deb: Add --deb-field for setting a custom field in the control file.  For more information on this setting, see section 5.7 "User-defined fields" of the debian policy manual: http://www.debian.org/doc/debian-policy/ch-controlfields.html#s5.7
* deb: Add --deb-recommends and --deb-suggests (`#285`_, `#310`_; patch by Pranay Kanwar)
* python to rpm: convert "!=" dependency operators in python to "Conflicts" in rpm. (`#263`_, `#312`_; patch by Pranay Kanwar)
* python: fix bug - ignore blank lines in requirements.txt (`#312`_, patch by Pranay Kanwar)

0.4.26 (December 27, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* rpm: add --rpm-sign flag to sign packages using the 'rpmbuild --sign' flag.  (`#311`_, Patch by Pranay Kanwar)
* rpm: fix flag ordering when calling rpmbuild (`#309`_, `#315`_, patch by Trotter Cashion)
* deb: re-enable "Predepends" support (`#319`_, `#320`_, patch by Pranay Kanwar)
* rpm: fix default 'rpm os' value (`#321`_, 314, 309)

0.4.25 (December 7, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^
* Added --deb-changelog and --rpm-changelog support flags. Both take a path to a changelog file. Both must be valid changelog formats for their respective package types. (`#300`_, patch by Pranay Kanwar)
* deb: Multiple "provides" are now supported. (`#301`_, patch by Pranay Kanwar)
* rpm: Added --rpm-os flag to set the OS target for the rpm. This lets you build rpms for linux on OS X and other platforms (with --rpm-os linux). (`#309`_)
* rpm: Avoid platform-dependent commands in the %install phase (`#309`_, fixes 'cp -d' on OSX)
* python: ignore comments in requirements.txt (`#304`_, patch by Pranay Kanwar)
* Fixed warning 'already initialized constant' (`#274`_)

0.4.24 (November 30, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* Don't include an empty url in rpm spec (`#296`_, `#276`_; patch by Pranay Kanwar)
* Don't require extra parameters if you use --inputs (`#278`_, `#297`_; Patch by Pranay Kanwar)
* python: supports requirements.txt now for dependency information.
* python: supports pip now. Use '--python-pip path/to/pip' to have fpm use it instead of easy_install.
* solaris: package building works again (`#216`_, `#299`_, patch by Pierre-Yves Ritschard)

0.4.23 (November 26, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* The --directories flag is now recursive when the output package is rpm.  This makes all directories under a given path as owned by the package so they'll be removed when the package is uninstalled (`#245`_, `#293`_, `#294`_, patch by Justin Ellison)
* Add fpm version info to '--help' output (`#281`_)
* gem to rpm: Use 'rubygem(gemname)' for dependencies (`#284`_, patch by Jan Vansteenkiste)
* Fix a bug in gem version mangling (`#292`_, `#291`_; patch by Pranay Kanwar)
* Fix compatibility with Python 2.5 (`#279`_, patch by Denis Bilenko)

0.4.22 (November 15, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* Add --no-depends flag for creating packages with no dependencies listed (`#289`_, patch by Brett Gailey)
* Fix a bug where blank lines were present in a debian control file.  (`#288`_, patch by Andrew Bunday)

0.4.21 (November 8, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^
* gem: remove restriction on expected gem names (`#287`_)
* add --directory flag; lets you mark a directory as being owned by a package. (`#260`_, `#245`_, patch by ajf8)
* deb: don't include a version in the Provides field (`#280`_)
* gem: if the version is '1.1' make it imply '1.1.0' (`#269`_, patch by Radim Marek)

0.4.20 (October 5, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^
* python: only specify --install-{scripts,lib,data} flags to setup.py if they were given on the command line to fpm. Fixes `#273`_.

0.4.19 (September 26, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Escape '%' characters in file names (`#266`_, `#222`_. Patch by John Wittkoski)

0.4.18 (September 25, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Fix regression in rpm building where the epoch in was missing in the rpm, but prior fpm versions defaulted it to 1. This caused rpms built with newer fpms to appear "older" than older rpms. Tests added to ensure this regression is caught prior to future releases! (Reported by eliklein)

0.4.17 (September 12, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^^
* Remove accidental JSON warning when using '-s python'

0.4.16 (September 6, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* Fix compatibility with Ruby 1.8.7 (broken in 0.4.15)

0.4.15 (September 6, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^^^
* pear: support custom channels with --pear-channel <channel> (`#207`_) Example: fpm -s pear -t deb --pear-channel pear.drush.org drush
* permit literal '\n' in --description, fpm will replace with a newline character. Example: fpm --description "line one\nline two" (`#251`_)
* improve error messaging when trying to output a package to a directory that doesn't exist (`#244`_)
* deb: convert '>' and '<' dependency operators to the correct '>>' and '<<' debian version operators (`#250`_, patch by Thomas Meson).
* deb: add --deb-priority flag (`#232`_) for setting the debian 'priority' value for your package.
* add --template-value. Used to expose arbitrary values to script templates.  If you do --template-value hello=world, in your template you can do <%= hello %> to get 'world' to show up in your maintainer scripts.
* python: add --python-install-data flag to set the --install-data option to setup.py (`#255`_, patch by Thomas Meson)
* Reject bad dependency flags (ones containing commas) and offer alternative.  (`#257`_)
* Try to copy a file if hardlinking fails with permission problems (`#253`_, patch by Jacek Lach)
* Make --exclude, if a directory, include itself and any children, recursive.  (`#248`_)

0.4.14 (August 24, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^
* rpm: Replace newlines with space in any license setting. (`#252`_)

0.4.13 (August 14, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^
* Make --exclude accept path prefixes as well. If you have a files in 'usr/share/man' in your package, you can now exclude all of a subdir by doing '--exclude usr/share/man'

0.4.12 (August 10, 2012)
^^^^^^^^^^^^^^^^^^^^^^^^
* Fix a major bug introduced in 0.4.11 that caused all deb packages to contain empty maintainer scripts if not otherwise specified, which made apt/dpkg quite unhappy

0.4.11 (August 7, 2012)
^^^^^^^^^^^^^^^^^^^^^^^
* Fix some symlink handling to prevent links from being followed during cleanup (`#228`_, patch by sbuss)
* rpm: 'vendor' in rpm spec is now omitted if empty or nil. This fixes a bug where rpmbuild fails due to empty 'Vendor' tag if you convert rpm to rpm.
* internal: remove empty directories marked by --exclude (`#205`_, patch by jimbrowne)
* dir: don't try to set utime on symlinks (`#234`_, `#240`_, patch by ctgswallow)
* rpm: relocatable rpms now supported when using the '--prefix' flag.  Example: fpm -s dir -t rpm --prefix /usr/local -n example /etc/motd (patch by jkoppe)
* deb: --deb-compression flag: Support different compression methods.  Default continues to be gzip.
* new flag: --template-scripts. This lets you write script templates for --after-install, etc. Templates are ERB, so you can do things like '<%= name %>' to get the package name in the script, etc.
* warn on command invocations that appear to have stray flags to try and help users who have complex command lines that are failling.

0.4.10 (May 25, 2012)
^^^^^^^^^^^^^^^^^^^^^
* Fix python package support for python3 (`#212`_, patch by Slezhuk Evgeniy)
* Preserve file metadata (time, owner, etc) when copying with the dir package. (`#217`_, patch by Marshall T. Vandegrift)
* Missing executables will now error more readably in fpm.
* Fix gem and python 'version' selection (`#215`_, `#204`_)
* Dependencies using '!=' will now map to 'Conflicts' in deb packages. (`#221`_, patch by Sven Fischer)
* Allow setting default user/group for files in rpm packages (`#208`_, patch by Jason Rogers). Note: This adds --user and --group flags to effect this.  These flags may go away in the future, but if they do, they will be
* In python packages set 'install-data' correctly. (`#223`_, patch by Jamie Scheinblum)

0.4.9 (April 25, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Fix --prefix support when building gems (`#213`_, patch by Jan Vansteenkiste)

0.4.8 (April 25, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* RPM: use 'noreplace' option for config files (`#194`_, patch by Steve Lum)
* Python: Fix bug around exact dependency versions (`#206`_, patch by Lars van de Kerkhof)
* Gem->RPM: Make 'provides' "rubygem(thegemname)" instead of "rubygem-thegemname"
* Fix oddity where Ruby would complain about constant redefinition (`#198`_, patch by Marcus Vinicius Ferreira)

0.4.7 skipped.
^^^^^^^^^^^^^^

0.4.6 (April 10, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Work around more problems in RPM with respect to file listing (`#202`_)

0.4.5 (April 3, 2012)
^^^^^^^^^^^^^^^^^^^^^
* Fix gem->rpm conversion where the '~>' rubygem version operator (`#193`_, patch by antoncohen)
* Escape filenames RPM install process (permits files with spaces, dollar signs, etc) (`#196`_, reported by pspiertz)

0.4.4 (March 30, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Fix a bug in gem bin_dir handling (Calen Pennington)
* The --config-files flag should work again (Brian Akins)
* Fix syntax error when using --deb-pre-depends (Andrew Bennett)
* Make --exclude work again (`#185`_, `#186`_) (Calen Pennington)
* Fix file listing so that rpm packages don't declare ownership on / and /usr, etc.
* make --deb-custom-control to work again (Tor Arne Vestbø)
* Add --rpm-digest flag to allow selection of the rpm 'file name' digest algorithm. Default is 'md5' since it works on the most rpm systems.
* Reimplement old behavior assuming "." as the input when using '-s dir' and also setting -C (`#187`_)
* Set BuildRoot on rpm to work around an rpmbuild bug(?) on CentOS 5 (`#191`_)
* Add --rpm-compression flag to allow selection of the rpm payload compression. Default is 'gzip' since it works on the most rpm systems
* Specs now pass on ubuntu/32bit systems (found by travis-ci.org's test runner)
* Improve default values of iteration and epoch (`#190`_)
* Make FPM::Package#files list only 'leaf' nodes (files, empty directories, symlinks, etc).

0.4.3 (March 21, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Fix bug in python packaging when invoked with a relative path to a setup.py (Reported by Thomas Meson, https://github.com/jordansissel/fpm/pull/180)

0.4.2 (March 21, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Set default temporary directory to /tmp (https://github.com/jordansissel/fpm/issues/174)
* Improve symlink handling (patch by Aleix Conchillo Flaqué, pull/177))
* Python package support changes (thanks to input by Luke Macken):

  * New flag: --python-install-bin. Sets the location for python package scripts (default: /usr/bin)
  * New flag: --python-install-lib. Sets the location for the python package to install libs to, default varies by system. Usually something like /usr/lib/python2.7/site-packages.
  * Fix up --prefix support
  * Improve staged package installation

0.4.1 (March 19, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Fix fpm so it works in ruby 1.8 again. Tests run, and passing: rvm 1.8.7,1.9.2,1.9.3 do bundle exec rspec

0.4.0 (March 18, 2012)
^^^^^^^^^^^^^^^^^^^^^^
* Complete rewrite of pretty much everything.

    * Otherwise, the 'fpm' command functionality should be the same
    * Please let me know if something broke!

* Now has an API (see examples/api directory)
* Also has a proper test suite
* Updated the rpm spec generator to disable all the ways I've found rpmbuild to be weird about packages. This means that fpm-generated rpms will no longer strip libraries, move files around, randomly mutate jar files, etc.
* Add --license and --vendor settings (via Pieter Loubser)
* python support: try to name python packages sanely. Some pypi packages are literally called 'python-foo' so make sure we generate packages named 'python-foo' and not 'python-python-foo' (via Thomas Meson)
* rpm support: Add --rpm-rpmbuild-define for passing a --define flag to rpmbuild (via Naresh V)
* PHP pear source support (fpm -s pear ...) (via Andrew Gaffney)

0.3.10 (Oct 10, 2011)
^^^^^^^^^^^^^^^^^^^^^
* Allow taking a list of files/inputs on stdin with '-' or with the --inputs flag. (Matt Patterson)
* (python) pass -U to easy_install (Khalid Goudeaux)
* (debian) quote paths in md5sum calls (Matt Patterson)
* (debian) quiet stderr from dpkg --print-architecture

0.3.9 (Sep 8, 2011)
^^^^^^^^^^^^^^^^^^^
* Fix bug in 'dir' source that breaks full paths
* Added a bunch of tests (yaay)

0.3.8 and earlier: I have not kept this file up to date very well... Sorry :(
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

0.2.29 (May 20, 2011)
^^^^^^^^^^^^^^^^^^^^^
* Add 'tar' source support. Useful for binary releases to repackage as rpms and debs. Example::

    fpm -s tar -t rpm -n firefox -v 4.0.1 --prefix /opt/firefox/4.0.1 firefox-4.0.1.tar.bz2

0.2.28 (May 18, 2011)
^^^^^^^^^^^^^^^^^^^^^
* Use --replaces as "Obsoletes" in rpms.

0.2.27 (May 18, 2011)
^^^^^^^^^^^^^^^^^^^^^
* If present, DEBEMAIL and DEBFULLNAME environment variables will be used as the default maintainer. Previously the default was simply <$user@$hostname> https://github.com/jordansissel/fpm/issues/37
* Add '--replaces' flag for specifying packages replaced by the one you are building. This only functions in .deb packages now until I find a suitable synonym in RPM.
* Add --python-bin and --python-easyinstall flags. This lets you choose specific python and easy_install tools to use when building. Default is simply 'python' and 'easy_install' respectively.
* Add support for ~/.fpmrc - The format of this file is the same as the flags.  One flag per line. https://github.com/jordansissel/fpm/issues/38. Example::

      --python-bin=/usr/bin/python2.7
      --python-easyinstall=/usr/bin/easy_install2.7

0.2.26 and earlier
^^^^^^^^^^^^^^^^^^
  No changelist tracked. My bad, yo.
