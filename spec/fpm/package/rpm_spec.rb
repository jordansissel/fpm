require "spec_setup"
require "fpm" # local
require "fpm/package/rpm" # local
require "fpm/package/dir" # local
require "arr-pm/file" # gem 'arr-pm'

describe FPM::Package::RPM do
  subject { FPM::Package::RPM.new }

  describe "#output" do
    context "package attributes" do
      before :all do
        @target = Tempfile.new("fpm-test-rpm")
        subject.name = "name"
        subject.version = "123"
        subject.iteration = "100"
        subject.epoch = "5"
        subject.dependencies << "something > 10"
        subject.dependencies << "hello >= 20"
        subject.output(@target.path)
        @rpm = ::RPM::File.new(@target.path)

        @rpmtags = {}
        @rpm.header.tags.each do |tag|
          @rpmtags[tag.tag] = tag.value
        end
      end

      after :all do
        subject.cleanup
        @target.close
        @target.delete
      end # after

      it "should have the correct name" do
        insist { @rpmtags[:name] } == subject.name
      end

      it "should have the correct version" do
        insist { @rpmtags[:version] } == subject.version
      end

      it "should have the correct iteration" do
        insist { @rpmtags[:release] } == subject.iteration
      end

      it "should have the correct epoch" do
        insist { @rpmtags[:epoch].first.to_s } == subject.epoch
      end

      it "should output a package with the correct dependencies" do
        # @rpm.requires is an array of [name, op, requires] elements
        # fpm uses strings here, so convert.
        requires = @rpm.requires.collect { |a| a.join(" ") }

        subject.dependencies.each do |dep|
          insist { requires }.include?(dep)
        end
      end
    end # package attributes

    describe "regressions should not occur"
      before :each do
        @target = Tempfile.new("fpm-test-rpm")
        subject.name = "name"
        subject.version = "123"
        subject.iteration = "100"
        subject.epoch = "5"
      end

      after :each do
        subject.cleanup
        @target.close
        @target.delete
      end # after

    it "should permit spaces in filenames (issue #164)" do
      File.write(subject.staging_path("file with space"), "Hello")

      # This will raise an exception if rpmbuild fails.
      subject.output(@target.path)
    end

  end # #output
end # describe FPM::Package::RPM
