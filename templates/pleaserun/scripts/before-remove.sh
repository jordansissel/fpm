#!/bin/sh

source="<%= attributes[:prefix] %>"

if [ -f "$source/cleanup.sh" ] ; then
  echo "Running cleanup to remove service for package <%= attributes[:name] %>"
  set -e
  sh "$source/cleanup.sh"

  # Remove the script also since the package installation generated it.
  rm "$source/cleanup.sh"
fi
