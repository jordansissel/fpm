require "spec_setup"
require "fpm" # local
require "fpm/package/python" # local

have_python = program_in_path?("python")
if !have_python
  Cabin::Channel.get("rspec") \
    .warn("Skipping Python#input tests because 'python' isn't in your PATH")
end

describe FPM::Package::Python, :if => have_python do
  let (:example_dir) do
    File.expand_path("../../fixtures/python/", File.dirname(__FILE__))
  end

  after :each do
    subject.cleanup
  end
  
  context "when :python_fix_name? is true" do
    before :each do
      subject.attributes[:python_fix_name?] = true
    end

    context "and :python_package_name_prefix is nil/default" do
      it "should prefix the package with 'python-'" do
        subject.input(example_dir)
        insist { subject.name } == "python-example"
      end
    end

    context "and :python_package_name_prefix is set" do
      it "should prefix the package name appropriately" do
        prefix = "whoa"
        subject.attributes[:python_package_name_prefix] = prefix
        subject.input(example_dir)
        insist { subject.name } == "#{prefix}-example"
      end
    end
  end

  context "when :python_fix_name? is false" do
    before :each do
      subject.attributes[:python_fix_name?] = false
    end

    it "it should not prefix the name at all" do
      subject.input(example_dir)
      insist { subject.name } == "example"
    end
  end
end # describe FPM::Package::Deb
