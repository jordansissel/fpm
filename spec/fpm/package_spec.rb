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

  describe "#version" do
    it "should default to '1.0'" do
      insist { subject.version } == "1.0"
    end

    it "should allow setting the package name" do
      version = "hello"
      subject.version = version
      insist { subject.version } == version
    end
  end

  describe "#architecture"
  describe "#attributes"
  describe "#category"
  describe "#config_files"
  describe "#conflicts"
  describe "#dependencies"
  describe "#description"
  describe "#epoch"
  describe "#iteration"
  describe "#license"
  describe "#maintainer"
  describe "#provides"
  describe "#replaces"
  describe "#scripts"
  describe "#url"
  describe "#vendor"
end # describe FPM::Package
