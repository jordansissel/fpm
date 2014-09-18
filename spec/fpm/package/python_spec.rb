require "spec_setup"
require "fpm" # local
require "fpm/package/python" # local
require "find" # stdlib

def python_usable?
  return program_exists?("python") && program_exists?("easy_install")
end

if !python_usable?
  Cabin::Channel.get("rspec").warn("Skipping Python#input tests because " \
    "'python' and/or 'easy_install' isn't in your PATH")
end

describe FPM::Package::Python, :if => python_usable? do
  let (:example_dir) do
    File.expand_path("../../fixtures/python/", File.dirname(__FILE__))
  end

  after :each do
    subject.cleanup
  end

  context "when :python_downcase_name? is false" do
    before :each do
      subject.attributes[:python_downcase_name?] = false
    end

    context "when :python_fix_name? is true" do
      before :each do
        subject.attributes[:python_fix_name?] = true
      end

      context "and :python_package_name_prefix is nil/default" do
        it "should prefix the package with 'python-'" do
          subject.input(example_dir)
          insist { subject.name } == "python-Example"
        end
      end

      context "and :python_package_name_prefix is set" do
        it "should prefix the package name appropriately" do
          prefix = "whoa"
          subject.attributes[:python_package_name_prefix] = prefix
          subject.input(example_dir)
          insist { subject.name } == "#{prefix}-Example"
        end
      end
    end

    context "when :python_fix_name? is false" do
      before :each do
        subject.attributes[:python_fix_name?] = false
      end

      it "should leave the package name as is" do
        subject.input(example_dir)
        insist { subject.name } == "Example"
      end
    end
  end

  context "when :python_downcase_name? is true" do
    before :each do
      subject.attributes[:python_downcase_name?] = true
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
  end

  context "when python_obey_requirements_txt? is true" do
    before :each do
      subject.attributes[:python_obey_requirements_txt?] = true
      subject.attributes[:python_dependencies?] = true
    end

    context "and :python_fix_dependencies? is true" do
      before :each do
        subject.attributes[:python_fix_dependencies?] = true
      end

      it "it should prefix requirements.txt" do
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["python-rtxt-dep1 > 0.1", "python-rtxt-dep2 = 0.1"]
      end
    end

    context "and :python_fix_dependencies? is false" do
      before :each do
        subject.attributes[:python_fix_dependencies?] = false
      end

      it "it should load requirements.txt" do
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["rtxt-dep1 > 0.1", "rtxt-dep2 = 0.1"]
      end
    end
  end

  context "python_scripts_executable is set" do
    it "should have scripts with a custom hashbang line" do
      subject.attributes[:python_install_bin] = '/usr/bin'
      subject.attributes[:python_scripts_executable] = "fancypants"
      subject.input("django")

      # Get the default scripts install directory and use it to find django-admin.py from Django
      # Then let's make sure the scripts executable setting worked!
      python_bindir = %x{python -c 'from distutils.sysconfig import get_config_var; print(get_config_var("BINDIR"))'}.chomp
      path = subject.staging_path(File.join(python_bindir, "django-admin.py"))

      # Read the first line (the hashbang line) of the django-admin.py script
      fd = File.new(path, "r")
      topline = fd.readline
      fd.close

      insist { topline.chomp } == "#!fancypants"
    end
  end
end # describe FPM::Package::Python
