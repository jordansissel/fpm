require "spec_setup"
require "fpm/package/container"
require "stud/temporary"

require "fpm/package/dir"

describe FPM::Package::Container do
  context "with commands" do
    after { subject.cleanup }

    it "should work maybe" do
      subject.input("touch /usr/bin/example")

      insist { File.stat(subject.staging_path("usr")) }.directory?
      insist { File.stat(subject.staging_path("usr/bin")) }.directory?
      insist { File.stat(subject.staging_path("usr/bin/example")) }.file?
    end

    context "with setup steps" do
      before do
        subject.attributes[:container_setup_list] = [
          "touch /usr/bin/example",
          "mkdir -p /hello/world",
        ]

        # Run a command which makes no file changes.
        subject.input("true")
      end

      let(:output) { subject.convert(FPM::Package::Dir) }

      after do
        output.cleanup
      end

      it "should not capture setup step file activity" do
        # Expect an empty staging path in the output package.
        output.staging_path
        insist { Dir.entries(output.staging_path) } == [".", ".."]
      end
    end
  end

  context "with Dockerfile or Containerfile" do
    before do
      subject.attributes[:excludes] = [ "etc/**", "etc" ]
    end

    let(:output) { subject.convert(FPM::Package::Dir) }

    after do
      subject.cleanup
      output.cleanup
    end

    context "and specifying the file directly" do
      let(:dockerfile) { File.expand_path("../../fixtures/container/Dockerfile", File.dirname(__FILE__)) }

      before do
        subject.input(dockerfile)
      end

      it "should use the dockerfile" do
        insist { Dir.entries(output.staging_path) } == [".", "..", "hello-world"]
      end
    end

    context "and giving a directory containing a Dockerfile or Containerfile" do
      let(:path) { File.expand_path("../../fixtures/container", File.dirname(__FILE__)) }

      before do
        subject.input(path)
      end

      it "should work" do
        insist { Dir.entries(output.staging_path) } == [".", "..", "hello-world"]
      end
    end

  end

end
