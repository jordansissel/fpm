require "spec_setup"
require "fpm" # local

describe "FPM::Package#convert" do

  let(:gem_package_name_prefix) { 'rubygem19' }
  let(:default_rpm_compression) { 'gzip' }

  subject do
    source = FPM::Package::Gem.new
    prefix = source.attributes[:gem_package_name_prefix ] = 'rubygem19'
    name = source.name = "whatever"
    version = source.version = "1.0"
    source.dependencies = ["something > 10", "another >= 1.2.3.rc4"]
    source.provides << "#{prefix}-#{name} = #{version}"
    source.convert(FPM::Package::RPM)
  end

  it "applies the default attributes for target format" do
    insist { subject.attributes[:rpm_compression] } == default_rpm_compression
  end

  it "remembers attributes applied to source" do
    insist { subject.attributes[:gem_package_name_prefix] } == gem_package_name_prefix
  end

  it "should list provides matching the gem_package_name_prefix (#585)" do
    insist { subject.provides }.include?("rubygem19(whatever) = 1.0")
  end

  it "should erase release candidate declariations from dependencies" do
    insist { subject.dependencies[0] } == "something > 10"
    insist { subject.dependencies[1] } == "another >= 1.2.3"
  end
end
