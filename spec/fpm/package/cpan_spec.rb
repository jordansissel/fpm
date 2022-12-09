require "spec_setup"
require "tmpdir" # for Dir.mktmpdir
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

  it "should unpack tarball containing ./ leading paths" do
    pending("Disabled on travis-ci because it always fails, and there is no way to debug it?") if is_travis

    Dir.mktmpdir do |tmpdir|
      # Create tarball containing a file './foo/bar.txt'
      system("mkdir -p #{tmpdir}/z/foo")
      system("touch #{tmpdir}/z/foo/bar.txt")
      system("tar -C #{tmpdir} -cvzf #{tmpdir}/z.tar.gz .")

      # Invoke the unpack method
      directory = subject.instance_eval { unpack("#{tmpdir}/z.tar.gz") }

      insist { File.file?("#{directory}/foo/bar.txt") } == true
    end
  end

  it "should package File::Spec" do
    pending("Disabled on travis-ci because it always fails, and there is no way to debug it?") if is_travis
    subject.input("File::Spec")

    # the File::Spec module comes from the PathTools CPAN distribution
    insist { subject.name } == "perl-PathTools"
  end

  it "should package Class::Data::Inheritable" do
    pending("Disabled on travis-ci because it always fails, and there is no way to debug it?") if is_travis

    # Class::Data::Inheritable version 0.08 has a blank author field in its
    # META.yml file.
    subject.instance_variable_set(:@version, "0.08");
    subject.input("Class::Data::Inheritable")
    insist { subject.vendor } == "No Vendor Or Author Provided"
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
