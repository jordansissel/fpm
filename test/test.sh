#!/bin/bash

fpm() {
  ../bin/fpm "$@" > $debugout 2> $debugerr
  status=$?

  if [ "$status" -ne 0 ] ; then
    fail
  fi
  return $status
}

cleanup() {
  rm -f $tmpout $debugout $debugerr
  [ ! -z "$tmpdir" ] && rm -r $tmpdir

  # Run clean if defined.
  if type clean 2> /dev/null | grep -q "function" ; then
    clean
  fi
}

main() {
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

  if [ $diffstatus -ne 0 ] ; then
    fail
  else
    ok
  fi
}

fail() { 
  echo "Fail: $test"
  sed -e 's/^/stdout: /' $debugout
  sed -e 's/^/stderr: /' $debugerr
  cleanup
  exit 1
}

ok() {
  echo "OK: $test"
  cleanup
  exit 0
}

main "$@"
