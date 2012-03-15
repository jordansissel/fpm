require "spec_setup"
require "fpm" # local
require "fpm/package/gem" # local

have_gem = program_in_path?("gem")
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
end # describe FPM::Package::Gem
