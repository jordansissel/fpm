require "spec_setup"
require 'fileutils'
require "fpm" # local
require "fpm/package/deb" # local
require "fpm/package/dir" # local
require "stud/temporary"
require "English" # for $CHILD_STATUS

describe FPM::Package::Pacman do
  let(:target) { Stud::Temporary.pathname + ".pkg.tar.xz" }
  after do
    subject.cleanup
    File.unlink(target) if File.exist?(target)
  end

  describe "#architecture" do
    it "should convert amd64 to x86_64" do
      subject.architecture = "amd64"
      expect(subject.architecture).to(be == "x86_64")
    end

    it "should convert noarch to any" do
      subject.architecture = "noarch"
      expect(subject.architecture).to(be == "any")
    end

    let(:native) { `uname -m`.chomp }

    it "should default to native" do
      # Convert kernel name to debian name
      expect(subject.architecture).to(be == native)
    end
  end

  describe "#iteration" do
    it "should default to 1" do
      expect(subject.iteration).to(be == 1)
    end
  end

  describe "#epoch" do
    it "should default to nil" do
      expect(subject.epoch).to(be_nil)
    end
  end

  describe "optdepends" do
    it "should default to []" do
      expect(subject.attributes[:optdepends]).to(be == [])
    end
  end

  describe "#to_s" do
    before do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "any"
      subject.iteration = "100"
      subject.epoch = "5"
    end

    it "should have a default output usable as a filename" do
      # This is the default filename I see commonly produced by debuild
      insist { subject.to_s } == "name-123-100-any.pkg.tar.xz"
    end

    context "when iteration is nil" do
      before do
        subject.iteration = nil
      end

      it "should have an iteration of `1`" do
        # This is the default filename I see commonly produced by debuild
        expect(subject.to_s).to(be == "name-123-1-any.pkg.tar.xz")
      end
    end
  end

  describe "#output" do
    let(:original) { FPM::Package::Pacman.new }
    let(:input) { FPM::Package::Pacman.new }

    before do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      # The target file must not exist.

      original.name = "name"
      original.version = "123"
      original.iteration = "100"
      original.epoch = "5"
      original.architecture = "all"
      original.dependencies << "something > 10"
      original.dependencies << "hello >= 20"
      original.provides << "#{original.name} = #{original.version}"

      original.conflicts = ["foo < 123"]
      original.attributes[:pacman_optdepends] = ["bamb > 10"]

      original.output(target)
      input.input(target)
    end

    after do
      original.cleanup
      input.cleanup
    end # after


    context "package attributes" do
      it "should have the correct name" do
        insist { input.name } == original.name
      end

      it "should have the correct version" do
        insist { input.version } == original.version
      end

      it "should have the correct iteration" do
        insist { input.iteration } == original.iteration
      end

      it "should have the correct epoch" do
        insist { input.epoch } == original.epoch
      end

      it "should have the correct dependencies" do
        original.dependencies.each do |dep|
          insist { input.dependencies }.include?(dep)
        end
      end

    end # package attributes
    # TODO: include a section that verifies that pacman can parse the package
  end # #output
end # describe FPM::Package::Pacman
