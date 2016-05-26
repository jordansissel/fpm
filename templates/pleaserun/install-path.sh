#!/bin/sh

install_path() {
  d="${1##.}"
  if [ ! -z "$d" ] ; then 
    if [ -d "$1" -a ! -d "$d" ] ; then 
      mkdir "$d"
    fi
    if [ -f "$1" ] ; then 
      cp -p "$1" "$d"
    fi
  fi
}

for i in "$@" ; do
  install_path "$i"
done
