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
    it "should default to nil" do
      insist { subject.version }.nil?
    end

    it "should allow setting the package name" do
      version = "hello"
      subject.version = version
      insist { subject.version } == version
    end
  end

  describe "#architecture" do
    it "should default to native" do
      insist { subject.architecture } == "native"
    end
  end

  describe "#attributes" do
    it "should be empty by default" do
      insist { subject.attributes }.empty?
    end
  end

  describe "#category" do
    it "should be 'default' by default" do
      insist { subject.category } == "default"
    end
  end

  describe "#config_files" do
    it "should be empty by default" do
      insist { subject.config_files }.empty?
    end
  end

  describe "#conflicts" do
    it "should be empty by default" do
      insist { subject.conflicts }.empty?
    end
  end

  describe "#dependencies" do
    it "should be empty by default" do
      insist { subject.dependencies }.empty?
    end
  end

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
