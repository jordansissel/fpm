require "spec_setup"
require "fpm" # local
require "fpm/command" # local

describe FPM::Command do
  describe "--prefix"
  describe "-C"
  describe "-p / --package"
  describe "-f"
  describe "-n"
  describe "-v"
  describe "--iteration"
  describe "--epoch"
  describe "--license"
  describe "--vendor"
  describe "--category"
  describe "-d / --depends"
  describe "--no-depends"
  describe "--provides"
  describe "--conflicts"
  describe "--replaces"
  describe "--config-files"
  describe "--directories"
  describe "-a | --architecture"
end
