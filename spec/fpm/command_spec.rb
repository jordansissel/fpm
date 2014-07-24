require "spec_setup"
require "stud/temporary"
require "fpm" # local
require "fpm/command" # local

describe FPM::Command do
  describe "--prefix"
  describe "-C"
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
end
