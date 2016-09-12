require "spec_setup"
require "stud/temporary"
require "fpm" # local
require "fpm/command" # local
require "fixtures/mockpackage"

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
end
