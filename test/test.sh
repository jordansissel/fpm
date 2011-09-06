#!/bin/sh

fpm() {
  ../bin/fpm "$@" > $debugout 2> $debugerr
}

cleanup() {
  rm -f $tmpout $debugout $debugerr
  [ ! -z "$tmpdir" ] && rm -r $tmpdir
}

main() {
  set -e
  test="$1"
  tmpdir=$(mktemp -d)
  debugout=$(mktemp)
  debugerr=$(mktemp)
  output=$(mktemp)
  expected=${1%.test}.out

  echo "Loading $test"
  . "./$test"

  # Run the test.
  run

  # Compare output
  diff -u $output $expected
  diffstatus=$?

  cleanup

  if [ $diffstatus -ne 0 ] ; then
    echo "Fail: $test"
    echo "FPM STDOUT"
    cat $debugout
    echo "FPM STDERR"
    cat $debugerr
    return 1
  else
    echo "OK: $test"
    return 0
  fi
}

main "$@"
