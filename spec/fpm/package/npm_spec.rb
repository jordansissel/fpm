require "spec_setup"
require "fpm" # local
require "fpm/package/npm" # local

describe FPM::Package::NPM, if: !HAVE_NPM do
  it 'dependencies' do
    skip("Missing npm")
  end
end

describe FPM::Package::NPM, if: HAVE_NPM do
  before do
    skip("Missing npm") unless HAVE_NPM
  end

  after do
    subject.cleanup
  end

  describe "::default_prefix" do
    it "should provide a valid default_prefix" do
      stat = File.stat(FPM::Package::NPM.default_prefix)
      insist { stat }.directory?
    end
  end
end # describe FPM::Package::NPM
