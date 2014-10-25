require "spec_setup"
require "fpm" # local
require "fpm/package/npm" # local

have_npm = program_exists?("npm")
if !have_npm
  Cabin::Channel.get("rspec") \
    .warn("Skipping NPM tests because 'npm' isn't in your PATH")
end

describe FPM::Package::NPM do
  after do
    subject.cleanup
  end

  describe "::default_prefix", :if => have_npm do
    it "should provide a valid default_prefix" do
      stat = File.stat(FPM::Package::NPM.default_prefix)
      insist { stat }.directory?
    end
  end
end # describe FPM::Package::NPM
