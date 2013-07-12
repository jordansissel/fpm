require "rubygems" # for ruby 1.8
require "insist" # gem "insist"
require "cabin" # gem "cabin"
require "tmpdir" # stdlib
require "tempfile" # stdlib
require "fileutils" # stdlib

# put "lib" in RUBYLIB
$: << File.join(File.dirname(File.dirname(__FILE__)), "lib")

# for method "program_in_path?" etc
require "fpm/util"
include FPM::Util

# Enable debug logs if requested.
if $DEBUG or ENV["DEBUG"]
  Cabin::Channel.get.level = :debug
  Cabin::Channel.get.subscribe(STDOUT)
end

spec_logger = Cabin::Channel.get("rspec")
spec_logger.subscribe(STDOUT)
spec_logger.level = :warn

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
