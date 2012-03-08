require "spec_setup"
require "fpm" # local
require "fpm/package/deb" # local
require "fpm/package/dir" # local

describe FPM::Package::Deb do
  subject { FPM::Package::Deb.new }

  describe "#output" do
    context "package attributes" do
      before :all do
        @target = Tempfile.new("fpm-test-deb")
        subject.name = "name"
        subject.version = "123"
        subject.iteration = "100"
        subject.epoch = "5"
        subject.dependencies << "something > 10"
        subject.dependencies << "hello >= 20"
        subject.output(@target.path)
      end

      after :all do
        subject.cleanup
        @target.close
        @target.delete
      end # after

      it "should have the correct name"
      it "should have the correct version"
      it "should have the correct iteration"
      it "should have the correct epoch"
      it "should output a package with the correct dependencies"
    end
  end
end # describe FPM::Package::RPM
