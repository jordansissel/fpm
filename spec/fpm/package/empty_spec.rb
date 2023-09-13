require "spec_setup"
require "fpm" # local

describe FPM::Package::Empty do
  describe "#to_s" do
    before do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = "100"
      subject.epoch = "5"
    end
    it "should always return the empty string" do
      expect(subject.to_s "NAME-VERSION-ITERATION.ARCH.TYPE").to(be == "")
      expect(subject.to_s "gobbledegook").to(be == "")
      expect(subject.to_s "").to(be == "")
      expect(subject.to_s nil).to(be == "")
    end
  end # describe to_s

  describe "#architecture" do
    it "should default to 'all'" do
      insist { subject.architecture } == "all"
    end

    it "should accept changing the architecture" do
      subject.architecture = "native"
      insist { subject.architecture } == "native"
    end
  end
end # describe FPM::Package::Empty
