require "rubygems" # for ruby 1.8
require "insist" # gem 'insist'
require "rush" # gem 'rush'
require "tmpdir" # stdlib
require "fileutils" # stdlib

# put 'lib' in RUBYLIB
$: << File.join(File.dirname(File.dirname(__FILE__)), "lib")

# Enable debug logs if requested.
if $DEBUG or ENV["DEBUG"]
  Cabin::Channel.get.level = :debug
  Cabin::Channel.get.subscribe(STDOUT)
end

