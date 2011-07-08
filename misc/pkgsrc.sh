#!/bin/sh

if [ ! -f "mk/bsd.pkg.mk" ]  ; then
  # TODO(sissel): Maybe download pkgsrc ourselves.
  echo "Current directory doesn't appear to be a pkgsrc tree. ($PWD)"
  echo "I was expecting to find file: ./mk/bsd.pkg.mk"
  exit 1
fi

if [ ! -f "build/usr/local/bin/bmake" ] ; then
  # TODO(sissel): Maybe bootstrap ourselves.
  echo "This script requires pkgsrc to be bootstrapped in a specific way."
  echo "I expected to find file: build/usr/local/bin/bmake and did not"
  echo
  echo "Bootstrap with:"
  echo "SH=/bin/bash ./bootstrap/bootstrap --unprivileged --prefix $PWD/build/usr/local --pkgdbdir $PWD/pkgdb"
  exit 1
fi

# TODO(sissel): put some flags.

LOCALBASE="/usr/local"
DESTDIR=$PWD/build

mkdir -p "$DESTDIR"

export PATH=$DESTDIR/$LOCALBASE/bin:$DESTDIR/$LOCALBASE/sbin:$PATH

for i in "$@" ; do
  # process dependencies first before the final target.
  set -- $(bmake -C "$@" show-depends-pkgpaths) "$@"
done

TARGETS="$*"

for target in $TARGETS; do
  set --

  eval "$(bmake -C $target show-vars-eval VARS="PKGNAME PKGVERSION")"
  name="$(echo "$PKGNAME" | sed -e "s/-$PKGVERSION\$//")"
  orig_version=${PKGVERSION}
  version=${PKGVERSION}-pkgsrc

  # Purge old package
  rm packages/All/$PKGNAME.tgz

  pkg_delete $name > /dev/null 2>&1

  bmake -C $target clean || exit 1
  bmake -C $target USE_DESTDIR=yes LOCALBASE=$LOCALBASE PREFIX=$LOCALBASE \
    DESTDIR=$DESTDIR SKIP_DEPENDS=yes \
    clean package || exit 1

  # Start building fpm args
  set -- -n "$name" -v "$version" --prefix $LOCALBASE

  # Skip the pkgsrc package metadata files
  set -- "$@" --exclude '+*'

  # Handle deps
  for dep in $(bmake -C $target show-depends-pkgpaths) ; do
    eval "$(bmake -C $dep show-vars-eval VARS="PKGNAME PKGVERSION")"
    PKGNAME="$(echo "$PKGNAME" | sed -e "s/-$PKGVERSION\$//")"
    set -- "$@" -d "$PKGNAME (= $PKGVERSION-pkgsrc)"
  done

  set -- -s tar -t deb "$@"
  set -- "$@" packages/All/$name-$orig_version.tgz
  fpm "$@"
done


