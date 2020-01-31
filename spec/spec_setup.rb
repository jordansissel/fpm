require "rubygems" # for ruby 1.8
require "insist" # gem "insist"
require "cabin" # gem "cabin"
require "tmpdir" # stdlib
require "tempfile" # stdlib
require "fileutils" # stdlib
require "date" # stdlib

# put "lib" in RUBYLIB
$: << File.join(File.dirname(File.dirname(__FILE__)), "lib")

# for method "program_exists?" etc
require "fpm/util"
include FPM::Util

# Enable debug logs if requested.
if $DEBUG or ENV["DEBUG"]
  Cabin::Channel.get.level = :debug
  Cabin::Channel.get.subscribe(STDOUT)
else
  class << Cabin::Channel.get
    alias_method :subscribe_, :subscribe
    def subscribe(io)
      return if io == STDOUT
      subscribe_(io)
      #puts caller.join("\n")
    end
  end
end

Cabin::Channel.get.level = :error
spec_logger = Cabin::Channel.get("rspec")
spec_logger.subscribe(STDOUT)
spec_logger.level = :error

# Quiet the output of all system() calls
module Kernel
  alias_method :orig_system, :system
  def system(*args)
    old_stdout = $stdout.clone
    old_stderr = $stderr.clone
    null = File.new("/dev/null", "w")
    $stdout.reopen(null)
    $stderr.reopen(null)
    value = orig_system(*args)
    $stdout.reopen(old_stdout)
    $stderr.reopen(old_stderr)
    null.close
    return value
  end
end

# Check various system dependancies.
# TODO: Move this into util somewhere, and conditionalize the fpm functions as well.

HAVE_MKSQUASHFS = program_exists?("mksquashfs")
if !HAVE_MKSQUASHFS
  Cabin::Channel.get("rspec") \
    .warn("Skipping some tests because 'mksquashfs' isn't in your PATH")
end

HAVE_DPKG_DEB = program_exists?("dpkg-deb")
if !HAVE_DPKG_DEB
  Cabin::Channel.get("rspec") \
    .warn("Skipping some deb tests because 'dpkg-deb' isn't in your PATH")
end

HAVE_LINTIAN = program_exists?("lintian")
if !HAVE_LINTIAN
  Cabin::Channel.get("rspec") \
    .warn("Skipping some deb tests because 'lintian' isn't in your PATH")
end

HAVE_NPM = program_exists?("npm")
if !HAVE_NPM
  Cabin::Channel.get("rspec") \
    .warn("Skipping NPM tests because 'npm' isn't in your PATH")
end

HAVE_CPANM = program_exists?("cpanm")
if !HAVE_CPANM
  Cabin::Channel.get("rspec") \
    .warn("Skipping CPAN#input tests because 'cpanm' isn't in your PATH")
end

HAVE_GEM = program_exists?("gem")
if !HAVE_GEM
  Cabin::Channel.get("rspec") \
    .warn("Skipping Gem#input tests because 'gem' isn't in your PATH")
end

HAVE_BSDTAR = program_exists?("bsdtar")
if !HAVE_BSDTAR
  Cabin::Channel.get("rspec") \
    .warn("Skipping pacman tests because 'pacman' isn't in your PATH")
end

HAVE_XZ = program_exists?("xz")
if !HAVE_XZ
  Cabin::Channel.get("rspec") \
    .warn("Skipping some tests because 'xz' isn't in your PATH, and it's needed by tar")
end

HAVE_RPMBUILD = program_exists?("rpmbuild")
if !HAVE_RPMBUILD
  Cabin::Channel.get("rspec") \
    .warn("Skipping RPM#output tests because 'rpmbuild' isn't in your PATH")
end

HAVE_USABLE_PYTHON = program_exists?("python") && program_exists?("easy_install")
if !HAVE_USABLE_PYTHON
    Cabin::Channel.get("rspec").warn("Skipping Python#input tests because " \
    "'python' and 'easy_install' isn't in your PATH")
end

HAVE_USABLE_VENV = program_exists?("virtualenv") && program_exists?("virtualenv-tools")
if !HAVE_USABLE_VENV
  Cabin::Channel.get("rspec").warn("Skipping python virtualenv tests because " \
                                   "no virtualenv/tools bin on your path")
end

IS_TRAVIS_CI = ENV["TRAVIS_OS_NAME"] && !ENV["TRAVIS_OS_NAME"].empty?
if IS_TRAVIS_CI
    Cabin::Channel.get("rspec").warn("On travis-ci, some tests will be skipped")
end

IS_OLD_RUBY = (RUBY_VERSION =~ /^((1\.)|(2\.0))/)
if IS_OLD_RUBY
  Cabin::Channel.get("rspec").warn("Old ruby, not all tests are supported")
end
