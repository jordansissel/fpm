require "spec_setup"
require "fpm" # local
require "fpm/package/sh" # local
require "tmpdir"

shell_is_bash = (%r{/bash} =~ ENV['SHELL'])
if !shell_is_bash
  Cabin::Channel.get("rspec").warn("Skipping SH pkg tests which require a BASH shell.")
end

describe FPM::Package::Sh do
  describe "#output", :if => shell_is_bash do
    def make_sh_package
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      tmpfile = Tempfile.new("fpm-test-sh")
      target = tmpfile.path
      # The target file must not exist.
      tmpfile.unlink

      original = FPM::Package::Sh.new
      yield original if block_given?
      original.output(target)

      return target, original
    end
    context "pre_install script" do
      before :all do
        @temptarget = Dir.mktmpdir()
        @target, @original = make_sh_package do |pkg|
          pkg.scripts[:before_install] = "#!/bin/sh\n\necho before_install"
        end
      end
      it "should execute a pre_install script" do
        output = `#{@target} -i #{@temptarget}`.split($/)
        insist { output.any? {|l| l.chomp == "before_install" }} == true
        insist { $?.success? } == true
      end
    end
    context "empty pre_install script" do
      before :all do
        @temptarget = Dir.mktmpdir()
        @target, @original = make_sh_package do |pkg|
          pkg.scripts[:before_install] = ""
        end
      end
      it "shouldn't choke even if the pre-install script is empty" do
        output = %x(#{@target} -i #{@temptarget})
        status = $?.success?
        insist { status } == true
      end
    end

    context "Contain segments" do
      before :all do
        @target, @original = make_sh_package
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
    end
  end # #output
end # describe FPM::Package::Sh

