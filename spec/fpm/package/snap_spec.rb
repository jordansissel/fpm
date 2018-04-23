require "spec_setup"
require "fpm" # local
require "English" # for $CHILD_STATUS

describe FPM::Package::Snap do
  let(:target) { Stud::Temporary.pathname + ".snap" }
  after do
    subject.cleanup
    File.unlink(target) if File.exist?(target)
  end

  describe "#to_s" do
    before do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = "100"
      subject.epoch = "5"
    end

    it "should have a default output usable as a filename" do
      # This is the default filename commonly produced by snapcraft
      insist { subject.to_s } == "name_123-100_all.snap"
    end

    context "when iteration is nil" do
      before do
        subject.iteration = nil
      end

      it "should not include iteration if it is nil" do
      # This is the default filename commonly produced by snapcraft
        expect(subject.to_s).to(be == "name_123_all.snap")
      end
    end
  end

  describe "#output" do
    let(:original) { FPM::Package::Snap.new }
    let(:input) { FPM::Package::Snap.new }

    before do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      # The target file must not exist.

      original.name = "name"
      original.version = "123"
      original.description = "summary\ndescription"
      original.architecture = "all"

      original.attributes[:snap_apps] = {
        "app1" => {
          "command" => "command1",
        },
        "app2" => {
          "command" => "command2",
          "daemon" => "simple",
        },
        "app3" => {
          "command" => "command3",
          "daemon" => "simple",
          "plugs" => ["test-plug"]
        },
      }

      original.attributes[:snap_hooks] = {
        "hook1" => nil,
        "hook2" => {
          "plugs" => ["test-plug"]
        },
      }
    end

    after do
      original.cleanup
      input.cleanup
    end

    context "package attributes" do
      before do
        original.output(target)
        input.input(target)
      end

      it "should have the correct name" do
        insist { input.name } == original.name
      end

      it "should have the correct version" do
        insist { input.version } == original.version
      end

      it "should have the correct description" do
        insist { input.description } == original.description
      end

      it "should have the correct architecture" do
        insist { input.architecture } == original.architecture
      end

      it "should have the correct apps" do
        insist { input.attributes[:snap_apps] } == original.attributes[:snap_apps]
      end

      it "should have the correct hooks" do
        insist { input.attributes[:snap_hooks] } == original.attributes[:snap_hooks]
      end
    end

    context "with custom snap.yaml" do
      let(:snap_yaml) { Stud::Temporary.pathname + ".yaml" }

      before do
        File.write(snap_yaml, {
          "name" => "custom-name",
          "version" => "custom-version",
          "summary" => "custom-summary",
          "description" => "custom-description",
          "architectures" => ["custom-architecture"],
        }.to_yaml)


        original.attributes[:snap_yaml] = snap_yaml
        original.output(target)
        input.input(target)
      end

      after do
        subject.cleanup
        File.unlink(snap_yaml) if File.exist?(snap_yaml)
      end

      it "should have the custom name" do
        insist { input.name } == "custom-name"
      end

      it "should have the custom version" do
        insist { input.version } == "custom-version"
      end

      it "should have the custom description" do
        insist { input.description } == "custom-summary\ncustom-description"
      end

      it "should have the custom architecture" do
        insist { input.architecture } == "custom-architecture"
      end

      it "should have the custom apps" do
        insist { input.attributes[:snap_apps] } == []
      end

      it "should have the custom hooks" do
        insist { input.attributes[:snap_hooks] } == []
      end
    end

    it "should support specifying confinement" do
      original.attributes[:snap_confinement] = "test-confinement"

      original.output(target)
      input.input(target)

      insist { input.attributes[:snap_confinement] } == "test-confinement"
    end

    it "should support specifying grade" do
      original.attributes[:snap_grade] = "test-grade"

      original.output(target)
      input.input(target)

      insist { input.attributes[:snap_grade] } == "test-grade"
    end
  end
end
