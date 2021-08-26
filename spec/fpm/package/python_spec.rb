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

is_travis = ENV["TRAVIS_OS_NAME"] && !ENV["TRAVIS_OS_NAME"].empty?

# Determine default value of a given easy_install's option
def easy_install_default(python_bin, option)
  result = nil
  execmd({:PYTHONPATH=>"#{example_dir}"}, python_bin, :stderr=>false) do |stdin,stdout|
    stdin.write("from easy_install_default import default_options\n" \
                "print default_options.#{option}\n")
    stdin.close
    result = stdout.read.chomp
  end
  return result
end

describe FPM::Package::Python do
  before do
    skip("Python and/or easy_install not found") unless python_usable?
  end

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

  context "when :python_dependencies is set" do
    before :each do
      subject.attributes[:python_dependencies] = true
    end

    it "it should include the dependencies from setup.py" do
      subject.input(example_dir)
      insist { subject.dependencies.sort } == ["python-dependency1  ","python-dependency2  "]
    end

    context "and :python_disable_dependency is set" do
      before :each do
        subject.attributes[:python_disable_dependency] = "Dependency1"
      end

      it "it should exclude the dependency" do
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["python-dependency2  "]
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
        insist { subject.dependencies.sort } == ["python-rtxt-dep1 > 0.1", "python-rtxt-dep2 = 0.1", "python-rtxt-dep4  "]
      end

      it "it should exclude the dependency" do
        subject.attributes[:python_disable_dependency] = "rtxt-dep1"
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["python-rtxt-dep2 = 0.1", "python-rtxt-dep4  "]
      end
    end

    context "and :python_fix_dependencies? is false" do
      before :each do
        subject.attributes[:python_fix_dependencies?] = false
      end

      it "it should load requirements.txt" do
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["rtxt-dep1 > 0.1", "rtxt-dep2 = 0.1", "rtxt-dep4  "]
      end

      it "it should exclude the dependency" do
        subject.attributes[:python_disable_dependency] = "rtxt-dep1"
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["rtxt-dep2 = 0.1", "rtxt-dep4  "]
      end
    end
  end

  context "python_scripts_executable is set" do
    it "should have scripts with a custom hashbang line" do
      pending("Disabled on travis-ci becaulamese it always fails, and there is no way to debug it?") if is_travis
      skip("Requires python3 executable") unless program_exists?("python3")

      subject.attributes[:python_scripts_executable] = "fancypants"
      # Newer versions of Django require Python 3.
      subject.attributes[:python_bin] = "python3"
      subject.input("django")

      # Determine, where 'easy_install' is going to install scripts
      #script_dir = easy_install_default(subject.attributes[:python_bin], 'script_dir')
      #path = subject.staging_path(File.join(script_dir, "django-admin.py"))

      # Hardcode /usr/local/bin here. On newer Python 3's I cannot figure out how to 
      # determine the script_dir at installation time. easy_install's method is gone.
      path = subject.staging_path("/usr/local/bin/django-admin.py")

      # Read the first line (the hashbang line) of the django-admin.py script
      fd = File.new(path, "r")
      topline = fd.readline
      fd.close

      insist { topline.chomp } == "#!fancypants"
    end
  end
end # describe FPM::Package::Python
