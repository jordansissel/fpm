require "spec_setup"
require "fpm" # local
require "fpm/package/gem" # local

have_gem = program_exists?("gem")
if !have_gem
  Cabin::Channel.get("rspec") \
    .warn("Skipping Gem#input tests because 'gem' isn't in your PATH")
end

describe FPM::Package::Gem, :if => have_gem do
  let (:example_gem) do
    File.expand_path("../../fixtures/gem/example/example-1.0.gem", File.dirname(__FILE__))
  end

  after :each do
    subject.cleanup
  end

  context "when :gem_version_bins? is true" do
    before :each do
      subject.attributes[:gem_version_bins?] = true
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it "it should append the version to binaries" do
      subject.input(example_gem)
      insist { ::Dir.entries(File.join(subject.staging_path, "/usr/bin")) }.include?("example-1.0.0")
    end
  end

  context "when :gem_version_bins? is false" do
    before :each do
      subject.attributes[:gem_version_bins?] = false
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it "it should not append the version to binaries" do
      subject.input(example_gem)
      insist { ::Dir.entries(File.join(subject.staging_path, "/usr/bin")) }.include?("example")
    end

  end

  context "when :gem_fix_name? is true" do
    before :each do
      subject.attributes[:gem_fix_name?] = true
    end

    context "and :gem_package_name_prefix is nil/default" do
      it "should prefix the package with 'gem-'" do
        subject.input(example_gem)
        insist { subject.name } == "rubygem-example"
      end
    end

    context "and :gem_package_name_prefix is set" do
      it "should prefix the package name appropriately" do
        prefix = "whoa"
        subject.attributes[:gem_package_name_prefix] = prefix
        subject.input(example_gem)
        insist { subject.name } == "#{prefix}-example"
      end
    end
  end

  context "when :gem_fix_name? is false" do
    before :each do
      subject.attributes[:gem_fix_name?] = false
    end

    it "it should not prefix the name at all" do
      subject.input(example_gem)
      insist { subject.name } == "example"
    end
  end

  context "when :gem_shebang is nil/default" do
    before :each do
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it 'should not change the shebang' do
      subject.input(example_gem)
      file_path = File.join(subject.staging_path, '/usr/bin/example')
      insist { File.readlines(file_path).grep(/^#!\/usr\/bin\/env /).any? } == true
    end
  end

  context "when :gem_shebang is set" do
    before :each do
      subject.attributes[:gem_shebang] = '/opt/special/bin/ruby'
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it 'should change the shebang' do
      subject.input(example_gem)
      file_path = File.join(subject.staging_path, '/usr/bin/example')
      insist { File.readlines(file_path).grep("#!/opt/special/bin/ruby\n").any? } == true
    end
  end
end # describe FPM::Package::Gem
