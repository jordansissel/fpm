* ``--osxpkg-dont-obsolete DONT_OBSOLETE_PATH``
    - A file path for which to 'dont-obsolete' in the built PackageInfo. Can be specified multiple times.
* ``--osxpkg-identifier-prefix IDENTIFIER_PREFIX``
    - Reverse domain prefix prepended to package identifier, ie. 'org.great.my'. If this is omitted, the identifer will be the package name.
* ``--osxpkg-ownership OWNERSHIP``
    - --ownership option passed to pkgbuild. Defaults to 'recommended'. See pkgbuild(1).
* ``--[no-]osxpkg-payload-free``
    - Define no payload, assumes use of script options.
* ``--osxpkg-postinstall-action POSTINSTALL_ACTION``
    - Post-install action provided in package metadata. Optionally one of 'logout', 'restart', 'shutdown'.

