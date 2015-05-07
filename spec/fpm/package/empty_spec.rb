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
end # describe FPM::Package::Deb
