require "spec_setup"
require "stud/temporary"
require "fpm" # local
require "fpm/command" # local
require "fixtures/mockpackage"
require "shellwords"

describe FPM::Command do
  describe "--prefix"
  describe "-C / --chdir"
  describe "-p / --package"
  describe "-f"
  describe "-n"
  describe "-v"
  describe "--iteration"
  describe "--epoch"
  describe "--license"
  describe "--vendor"
  describe "--category"
  describe "-d / --depends"
  describe "--no-depends"
  describe "--provides"
  describe "--conflicts"
  describe "--replaces"
  describe "--config-files"
  describe "--directories"
  describe "-a | --architecture"

  describe "--workdir" do
    subject { FPM::Command.new("fpm") }

    context "with an nonexistent path" do
      it "should fail aka return nonzero exit" do
        args = ["--workdir", "/this/path/should/not/exist", "-s", "rpm", "-t", "empty", "-n", "example"]
        insist { subject.run(args) } != 0
      end
    end

    context "with a path that is not a directory" do
      it "should fail aka return nonzero exit" do
        Stud::Temporary.file do |file|
          args = ["--workdir", file.path, "-s", "rpm", "-t", "empty", "-n", "example"]
          insist { subject.run(args) } != 0
        end
      end
    end

  end

  describe "-v | --version" do
    subject { FPM::Command.new("fpm") }

    # Have output from `fpm` cli be nulled.
    let(:null) { File.open(File::NULL, "w") }
    let!(:stdout) { $stdout }

    before do
      $stdout = null
    end

    after do
      $stdout = stdout
    end

    context "when no rc file is present" do
      it "should not fail" do
        stub_const('ARGV', ["--version"])
        insist { subject.run(["--version"]) } == 0

        stub_const('ARGV', ["-v"])
        insist { subject.run(["-v"]) } == 0
      end
    end

    context "when rc file is present" do
      it "should not fail" do
        Stud::Temporary.directory do |path|
          File.open(File.join(path, ".fpm"), "w") { |file| file.puts("-- --rpm-sign") }

          stub_const('ARGV', [ "--version" ])
          insist { subject.run(["--version"]) } == 0

          stub_const('ARGV', [ "-v" ])
          insist { subject.run(["-v"]) } == 0
        end
      end
    end
  end

  describe "-p | --package" do
    context "when given a directory" do
      it "should write the package to the given directory." do
        Stud::Temporary.directory do |path|
          cmd = FPM::Command.new("fpm")
          cmd.run(["-s", "empty", "-t", "deb", "-n", "example", "-p", path])
          files = Dir.new(path).to_a - [".", ".."]

          insist { files.size } == 1
          insist { files[0] } =~ /^example_/
        end
      end
    end

    context "when not set" do
      it "should write the package to the current directory." do
        Stud::Temporary.directory do |path|
          Dir.chdir(path) do
            cmd = FPM::Command.new("fpm")
            cmd.run(["-s", "empty", "-t", "deb", "-n", "example"])
          end
          files = Dir.new(path).to_a - ['.', '..']
          insist { files.size } == 1
          insist { files[0] } =~ /example_/
        end
      end
    end
  end

  describe "--log" do
    subject { FPM::Command.new("fpm") }
    let (:args) { [ "-s", "mock", "-t", "mock" ] }

    context "when not given" do
      it "should not raise an exception" do
        subject.parse(args)
      end
    end
    context "when given a valid log level" do
      it "should not raise an exception" do
        subject.parse(args + ["--log", "error"])
        subject.parse(args + ["--log", "warn"])
        subject.parse(args + ["--log", "info"])
        subject.parse(args + ["--log", "debug"])
      end
    end
    context "when given an invalid log level" do
      it "should raise an exception" do
        insist { subject.parse(args + ["--log", ""]) }.raises FPM::Package::InvalidArgument
        insist { subject.parse(args + ["--log", "whatever"]) }.raises FPM::Package::InvalidArgument
        insist { subject.parse(args + ["--log", "fatal"]) }.raises FPM::Package::InvalidArgument
      end
    end
  end

  describe "--fpm-options-file" do
    let(:path) { Stud::Temporary.pathname }
    subject = FPM::Command.new("fpm")

    after do
      File.unlink(path) if File.exist?(path)
    end

    context "when considering option order" do
      before do
        File.write(path, [
          "--name file-value",
        ].join($/))
      end

      it "should process options file content in-place" do
        cli = [ "--name", "cli-value" ]
        fileopt = [ "--fpm-options-file", path ]

        subject.parse(cli + fileopt)
        insist { subject.name } == "file-value"

        subject = FPM::Command.new("fpm")
        subject.parse(fileopt + cli)
        insist { subject.name } == "cli-value"
      end
    end

    context "with multiple flags on a single line" do
      before do
        File.write(path, [
          "--version 123 --name fancy",
        ].join($/))
      end

      it "should work" do
        subject.parse(["--fpm-options-file", path])
        insist { subject.name } == "fancy"
        insist { subject.version } == "123"
      end
    end

    context "with multiple single-letter flags on a single line" do
      subject { FPM::Command.new("fpm") }

      context "separately" do
        before do
          File.write(path, [
            "-f -f -f -f"
          ].join($/))
        end

        it "should work" do
          subject.parse(["--fpm-options-file", path])
        end
      end

      context "together" do
        before do
          File.write(path, [
            "-ffff"
          ].join($/))
        end

        it "should work" do
          subject.parse(["--fpm-options-file", path])
        end
      end
    end

    context "when a file refers to itself" do
      subject { FPM::Command.new("fpm") }

      before do
        File.write(path, [
          "--version 1.0",
          "--fpm-options-file #{Shellwords.shellescape(path)}",
          "--iteration 1",
        ].join($/))
      end

      it "should raise an exception" do
        insist { subject.parse([ "--fpm-options-file", Shellwords.shellescape(path) ]) }.raises FPM::Package::InvalidArgument
      end

    end

    context "when using an nonexistent file" do
      it "should raise an exception" do
        # At this point, 'path' file hasn't been created, so we should be safe to assume it doesn't exist.
        insist { subject.parse([ "--fpm-options-file", path ]) }.raises Errno::ENOENT
      end

    end

    context "when using an unreadable file (no permission to read)" do
      it "should raise an exception" do
        File.write(path, "")
        File.chmod(000, path)
        # At this point, 'path' file hasn't been created, so we should be safe to assume it doesn't exist.
        insist { subject.parse([ "--fpm-options-file", path ]) }.raises Errno::EACCES
      end
    end

    context "when reading a large file" do
      let(:fd) { File.new(path, "w") }

      before do
        # Write more than 100kb
        max = 105 * 1024
        data = "\n" * 4096

        bytes = 0
        bytes += fd.syswrite(data) while bytes < max

        fd.flush
      end

      after do
        fd.close
      end

      it "should raise an exception" do
        insist { subject.parse([ "--fpm-options-file", path ]) }.raises FPM::Package::InvalidArgument
      end
    end
  end
end
