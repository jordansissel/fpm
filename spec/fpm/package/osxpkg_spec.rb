require "spec_setup"
require "fpm" # local
require "fpm/package/osxpkg" # local

platform_is_darwin = (%x{uname -s}.chomp == "Darwin")
if !platform_is_darwin
  Cabin::Channel.get("rspec").warn("Skipping OS X pkg tests requiring 'pkgbuild', " \
      "which requires a Darwin platform.")
end

describe FPM::Package::OSXpkg do
  describe "#identifier" do
    it "should be of the form reverse.domain.pkgname" do
      subject.name = "name"
      subject.attributes[:osxpkg_identifier_prefix] = "org.great"
      insist { subject.identifier } == \
      "#{subject.attributes[:osxpkg_identifier_prefix]}.#{subject.name}"
    end

    it "should be the name only if a prefix was not given" do
      subject.name = "name"
      subject.attributes[:osxpkg_identifier_prefix] = nil
      insist { subject.identifier } == subject.name
    end
  end

  describe "#to_s" do
    it "should have a default output usable as a filename" do
      subject.name = "name"
      subject.version = "123"

      # We like the format 'name-version.pkg'
      insist { subject.to_s } == "name-123.pkg"
    end
  end

  describe "#output", :if => platform_is_darwin do 
    before :all do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      tmpfile = Tempfile.new("fpm-test-osxpkg")
      @target = tmpfile.path
      # The target file must not exist.
      tmpfile.unlink

      @original = FPM::Package::OSXpkg.new
      @original.name = "name"
      @original.version = "123"
      @original.attributes[:osxpkg_identifier_prefix] = "org.my"
      @original.output(@target)

      @input = FPM::Package::OSXpkg.new
      @input.input(@target)
    end

    after :all do
      @original.cleanup
      @input.cleanup
    end # after

    context "package attributes" do
      it "should have the correct name" do
        insist { @input.name } == @original.name
      end

      it "should have the correct version" do
        insist { @input.version } == @original.version
      end
    end # package attributes
  end # #output
end # describe FPM::Package:OSXpkg