require "spec_setup"
require "fpm" # local

describe FPM::Package do
  before :each do
    subject { FPM::Package.new }
  end # before

  after :each do
    subject.cleanup
  end # after

  describe "#name" do
    it "should have no default name" do
      insist { subject.name }.nil?
    end

    it "should allow setting the package name" do
      name = "my-package"
      subject.name = name
      insist { subject.name } == name
    end
  end
end # describe FPM::Package
