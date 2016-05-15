#!/bin/sh

source="<%= attributes[:prefix] %>"
exec sh "$source/install.sh"
