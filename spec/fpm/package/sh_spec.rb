require "spec_setup"
require "fpm" # local
require "fpm/package/sh" # local

shell_is_bash = (%r{/bash} =~ ENV['SHELL'])
if !shell_is_bash
  Cabin::Channel.get("rspec").warn("Skipping SH pkg tests which require a BASH shell.")
end

describe FPM::Package::Sh do
  describe "#output", :if => shell_is_bash do
    before :all do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      tmpfile = Tempfile.new("fpm-test-sh")
      @target = tmpfile.path
      # The target file must not exist.
      tmpfile.unlink

      @original = FPM::Package::Sh.new
      @original.output(@target)
    end

    after :all do
      @original.cleanup
    end # after

    context "package contents" do
      it "should contain a ARCHIVE segment" do
        insist { File.readlines(@target).any? {|l| l.chomp == '__ARCHIVE__' } } == true
      end

      it "should contain a METADATA segment" do
        insist { File.readlines(@target).any? {|l| l.chomp == '__METADATA__' } } == true
      end
    end # package attributes
  end # #output
end # describe FPM::Package::Sh

