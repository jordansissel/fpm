* ``--rpm-attr ATTRFILE``
    - Set the attribute for a file (%attr), e.g. --rpm-attr 750,user1,group1:/some/file
* ``--[no-]rpm-auto-add-directories``
    - Auto add directories not part of filesystem
* ``--rpm-auto-add-exclude-directories DIRECTORIES``
    - Additional directories ignored by '--rpm-auto-add-directories' flag
* ``--[no-]rpm-autoprov``
    - Enable RPM's AutoProv option
* ``--[no-]rpm-autoreq``
    - Enable RPM's AutoReq option
* ``--[no-]rpm-autoreqprov``
    - Enable RPM's AutoReqProv option
* ``--rpm-changelog FILEPATH``
    - Add changelog from FILEPATH contents
* ``--rpm-compression none|xz|xzmt|gzip|bzip2``
    - Select a compression method. gzip works on the most platforms.
* ``--rpm-compression-level [0-9]``
    - Select a compression level. 0 is store-only. 9 is max compression.
* ``--rpm-defattrdir ATTR``
    - Set the default dir mode (%defattr).
* ``--rpm-defattrfile ATTR``
    - Set the default file mode (%defattr).
* ``--rpm-digest md5|sha1|sha256|sha384|sha512``
    - Select a digest algorithm. md5 works on the most platforms.
* ``--rpm-dist DIST-TAG``
    - Set the rpm distribution.
* ``--rpm-filter-from-provides REGEX``
    - Set %filter_from_provides to the supplied REGEX.
* ``--rpm-filter-from-requires REGEX``
    - Set %filter_from_requires to the supplied REGEX.
* ``--rpm-group GROUP``
    - Set the group to GROUP in the %files section. Overrides the group when used with use-file-permissions setting.
* ``--[no-]rpm-ignore-iteration-in-dependencies``
    - For '=' (equal) dependencies, allow iterations on the specified version. Default is to be specific. This option allows the same version of a package but any iteration is permitted
* ``--rpm-init FILEPATH``
    - Add FILEPATH as an init script
* ``--[no-]rpm-macro-expansion``
    - install-time macro expansion in %pre %post %preun %postun scripts (see: https://rpm.org/user_doc/scriptlet_expansion.html)
* ``--rpm-os OS``
    - The operating system to target this rpm for. You want to set this to 'linux' if you are using fpm on OS X, for example
* ``--rpm-posttrans FILE``
    - posttrans script
* ``--rpm-pretrans FILE``
    - pretrans script
* ``--rpm-rpmbuild-define DEFINITION``
    - Pass a --define argument to rpmbuild.
* ``--[no-]rpm-sign``
    - Pass --sign to rpmbuild
* ``--rpm-summary SUMMARY``
    - Set the RPM summary. Overrides the first line on the description if set
* ``--rpm-tag TAG``
    - Adds a custom tag in the spec file as is. Example: --rpm-tag 'Requires(post): /usr/sbin/alternatives'
* ``--rpm-trigger-after-install '[OPT]PACKAGE: FILEPATH'``
    - Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--rpm-trigger-after-target-uninstall '[OPT]PACKAGE: FILEPATH'``
    - Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--rpm-trigger-before-install '[OPT]PACKAGE: FILEPATH'``
    - Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--rpm-trigger-before-uninstall '[OPT]PACKAGE: FILEPATH'``
    - Adds a rpm trigger script located in FILEPATH, having 'OPT' options and linking to 'PACKAGE'. PACKAGE can be a comma seperated list of packages. See: http://rpm.org/api/4.4.2.2/triggers.html
* ``--[no-]rpm-use-file-permissions``
    - Use existing file permissions when defining ownership and modes.
* ``--rpm-user USER``
    - Set the user to USER in the %files section. Overrides the user when used with use-file-permissions setting.
* ``--[no-]rpm-verbatim-gem-dependencies``
    - When converting from a gem, leave the old (fpm 0.4.x) style dependency names. This flag will use the old 'rubygem-foo' names in rpm requires instead of the redhat style rubygem(foo).
* ``--rpm-verifyscript FILE``
    - a script to be run on verification

