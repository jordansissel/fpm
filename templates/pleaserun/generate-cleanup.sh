#!/bin/sh

show_cleanup_step() {
  d="${1##.}"
  if [ ! -z "$d" ] ; then 
    if [ -d "$1" -a ! -d "$d" ] ; then 
      echo "rmdir \"$d\""
    fi
    if [ -f "$1" ] ; then 
      echo "rm \"$d\""
    fi
  fi
}

for i in "$@" ; do
  show_cleanup_step "$i"
done
