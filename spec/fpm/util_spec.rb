require "spec_setup"
require "fpm" # local

describe FPM::Util do
  subject do
    Class.new do
      include FPM::Util
      def initialize
        @logger = Cabin::Channel.new
      end
    end.new
  end

  describe "#safesystem" do
    context "with a missing $SHELL" do
      before do
        @orig_shell = ENV["SHELL"]
        ENV.delete("SHELL")
      end

      after do
        ENV["SHELL"] = @orig_shell unless @orig_shell.nil?
      end

      it "should assume /bin/sh"  do
        insist { subject.default_shell } == "/bin/sh"
      end

      it "should still run commands correctly" do
        # This will raise an exception if we can't run it at all.
        subject.safesystem("true")
      end
    end
    context "with $SHELL set to an empty string" do 
      before do
        @orig_shell = ENV["SHELL"]
        ENV["SHELL"] = ""
      end

      after do
        ENV["SHELL"] = @orig_shell unless @orig_shell.nil?
      end

      it "should assume /bin/sh"  do
        insist { subject.default_shell } == "/bin/sh"
      end

      it "should still run commands correctly" do
        # This will raise an exception if we can't run it at all.
        subject.safesystem("true")
      end
    end
  end
end
