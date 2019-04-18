`cpan` - Perl packages
======================

A basic example:

`fpm -t deb -s cpan Fennec`

The above will download Fennec from CPAN and build a Debian package of the Fennec Perl module locally. 

By default, fpm believes the following to be true:

1. That your local Perl lib path will be the target Perl lib path
2. That you want the package name to be prefixed with the word perl
3. That the dependencies from CPAN are valid and that the naming scheme for those dependencies are prefixed with perl

If you wish to avoid any of those issues you can try:

`fpm -t deb -s cpan --cpan-perl-lib-path /usr/share/perl5 Fennec`

This will change the target path to where perl will be. Your local perl install may be /opt/usr/share/perl5.10 but the package will be constructed so that the module will be installed to /usr/share/perl5

`fpm -t deb -s cpan --cpan-package-name-prefix fubar Fennec`
This will replace the perl default prefix with fubar. The resulting package will be named in the scheme of fubar-fennec-2.10.deb

`fpm -t -deb -s cpan --no-depends Fennec`
This will remove omit dependencies from being added to the package metadata.

A full list of available options for CPAN are listed here::

    --cpan-perl-bin PERL_EXECUTABLE (cpan only) The path to the perl executable you wish to run. (default: "perl")
    --cpan-cpanm-bin CPANM_EXECUTABLE (cpan only) The path to the cpanm executable you wish to run. (default: "cpanm")
    --cpan-mirror CPAN_MIRROR     (cpan only) The CPAN mirror to use instead of the default.
    --[no-]cpan-mirror-only       (cpan only) Only use the specified mirror for metadata. (default: false)
    --cpan-package-name-prefix NAME_PREFIX (cpan only) Name to prefix the package name with. (default: "perl")
    --cpan-deps-name-prefix DEPS_PREFIX (cpan only) Name to prefix the package dependency names with. (default: "perl")
    --[no-]cpan-test              (cpan only) Run the tests before packaging? (default: true)
    --cpan-perl-lib-path PERL_LIB_PATH (cpan only) Path of target Perl Libraries
    --[no-]cpan-sandbox-non-core  (cpan only) Sandbox all non-core modules, even if they're already installed (default: true)
    --[no-]cpan-cpanm-force       (cpan only) Pass the --force parameter to cpanm (default: false)
