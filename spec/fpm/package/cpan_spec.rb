require "spec_setup"
require "fpm" # local
require "fpm/package/cpan" # local

have_cpanm = program_in_path?("cpanm")
if !have_cpanm
  Cabin::Channel.get("rspec") \
    .warn("Skipping CPAN#input tests because 'cpanm' isn't in your PATH")
end

describe FPM::Package::CPAN, :if => have_cpanm do
  subject { FPM::Package::CPAN.new }

  after :each do
    subject.cleanup
  end

  it "should package Digest::MD5" do
    subject.input("Digest::MD5")
    insist { subject.name } == "perl-Digest-MD5"
    insist { subject.description } == "Perl interface to the MD-5 algorithm"
    insist { subject.vendor } == "Gisle Aas <gisle@activestate.com>"
    # TODO(sissel): Check dependencies
  end

  it "should package File::Spec" do
    subject.input("File::Spec")

    # the File::Spec module comes from the PathTools CPAN distribution
    insist { subject.name } == "perl-PathTools"
  end
end # describe FPM::Package::CPAN
