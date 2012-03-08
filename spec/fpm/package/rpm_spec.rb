require "spec_setup"
require "fpm" # local
require "fpm/package/rpm" # local
require "fpm/package/dir" # local
require "rpm" # gem arr-pm

describe FPM::Package::RPM do
  subject { FPM::Package::RPM.new }

  before :each do
    @target = Tempfile.new("fpm-test-rpm")
  end # before

  after :each do
    subject.cleanup
    @target.close
  end # after

  describe "#output" do
    context "basics" do
      before :each do
        subject.name = "name"
      end

      it "should output a package with the correct name" do
        subject.output(@target.path)
        rpm = RPM::File.new(@target.path)
        # TODO(sissel): verify rpm name vs subject.name
      end

      it "should output a package with the correct version"
      it "should output a package with the correct iteration"
      it "should output a package with the correct epoch"
      it "should output a package with the correct dependencies"
    end
  end
end # describe FPM::Package::RPM
