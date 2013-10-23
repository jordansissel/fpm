require "spec_setup"
require "fpm" # local

describe "FPM::Package#convert" do

    let(:gem_package_name_prefix) { 'rubygem19' }
    let(:default_rpm_compression) { 'gzip' }

    subject do
      source = FPM::Package::Gem.new
      source.attributes[:gem_package_name_prefix ] = 'rubygem19'
      source.convert(FPM::Package::RPM)
    end

    it "applies the default attributes for target format" do
      insist { subject.attributes[:rpm_compression] } == default_rpm_compression
    end

    it "remembers attributes applied to source" do
      insist { subject.attributes[:gem_package_name_prefix] } == gem_package_name_prefix
    end
end
