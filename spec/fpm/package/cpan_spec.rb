require "spec_setup"
require "fpm" # local
require "fpm/package/cpan" # local

have_cpanm = program_exists?("cpanm")
if !have_cpanm
  Cabin::Channel.get("rspec") \
    .warn("Skipping CPAN#input tests because 'cpanm' isn't in your PATH")
end

is_travis = ENV["TRAVIS_OS_NAME"] && !ENV["TRAVIS_OS_NAME"].empty?

describe FPM::Package::CPAN do
  before do
    skip("Missing cpanm program") unless have_cpanm
  end

  subject { FPM::Package::CPAN.new }

  after :each do
    subject.cleanup
  end

  it "should package Digest::MD5" do
    pending("Disabled on travis-ci because it always fails, and there is no way to debug it?") if is_travis

    # Disable testing because we don't really need to run the cpan tests. The
    # goal is to see the parsed result (name, module description, etc)
    # Additionally, it fails on my workstation when cpan_test? is enabled due
    # to not finding `Test.pm`, and it seems like a flakey test if we keep this
    # enabled.
    subject.attributes[:cpan_test?] = false
    subject.input("Digest::MD5")
    insist { subject.name } == "perl-Digest-MD5"
    insist { subject.description } == "Perl interface to the MD-5 algorithm"
    insist { subject.vendor } == "Gisle Aas <gisle@activestate.com>"
    # TODO(sissel): Check dependencies
  end

  it "should package File::Spec" do
    pending("Disabled on travis-ci because it always fails, and there is no way to debug it?") if is_travis
    subject.input("File::Spec")

    # the File::Spec module comes from the PathTools CPAN distribution
    insist { subject.name } == "perl-PathTools"
  end

  context "given a distribution without a META.* file" do
    it "should package IPC::Session" do
      pending("Disabled on travis-ci because it always fails, and there is no way to debug it?") if is_travis

      # IPC::Session fails 'make test'
      subject.attributes[:cpan_test?] = false
      subject.input("IPC::Session")
    end
  end
end # describe FPM::Package::CPAN
