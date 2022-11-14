* ``--gem-bin-path DIRECTORY``
    - The directory to install gem executables
* ``--gem-disable-dependency gem_name``
    - The gem name to remove from dependency list
* ``--[no-]gem-embed-dependencies``
    - Should the gem dependencies be installed?
* ``--[no-]gem-env-shebang``
    - Should the target package have the shebang rewritten to use env?
* ``--[no-]gem-fix-dependencies``
    - Should the package dependencies be prefixed?
* ``--[no-]gem-fix-name``
    - Should the target package name be prefixed?
* ``--gem-gem PATH_TO_GEM``
    - The path to the 'gem' tool (defaults to 'gem' and searches your $PATH)
* ``--gem-git-branch GIT_BRANCH``
    - When using a git repo as the source of the gem instead of rubygems.org, use this git branch.
* ``--gem-git-repo GIT_REPO``
    - Use this git repo address as the source of the gem instead of rubygems.org.
* ``--gem-package-name-prefix PREFIX``
    - Name to prefix the package name with.
* ``--gem-package-prefix NAMEPREFIX``
    - (DEPRECATED, use --package-name-prefix) Name to prefix the package name with.
* ``--[no-]gem-prerelease``
    - Allow prerelease versions of a gem
* ``--gem-shebang SHEBANG``
    - Replace the shebang in the executables in the bin path with a custom string
* ``--gem-stagingdir STAGINGDIR``
    - The directory where fpm installs the gem temporarily before conversion. Normally a random subdirectory of workdir.
* ``--[no-]gem-version-bins``
    - Append the version to the bins

