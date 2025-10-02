require "spec_setup"
require "fpm" # local
require "fpm/package/python" # local
require "find" # stdlib

def find_python
  [ "python", "python3", "python2" ].each do |i|
    return i if program_exists?(i)
  end
  return nil
end

def python_usable?
  return find_python
end

if !python_usable?
  Cabin::Channel.get("rspec").warn("Skipping Python#input tests because 'python' wasn't found in $PATH")
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
    skip("Python program not found") unless python_usable?
    #subject.attributes[:python_bin] = find_python
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
        it "should prefix the package name based on detected python-bin name" do
          subject.input(example_dir)
          insist { subject.name } == "#{subject.attributes[:python_bin]}-Example"
        end
      end

      context "and :python_package_name_prefix is set" do
        it "should prefix the package name appropriately" do
          prefix = "whoa"
          subject.attributes[:python_package_name_prefix] = prefix
          subject.attributes[:python_package_name_prefix_given?] = true
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
        it "should prefix the package based on the version of python" do
          subject.input(example_dir)
          insist { subject.attributes[:python_package_name_prefix_given?] }.nil?
          insist { subject.name } == "#{subject.attributes[:python_bin]}-example"
        end
      end

      context "and :python_package_name_prefix is set" do
        it "should prefix the package name appropriately" do
          prefix = "whoa"
          subject.attributes[:python_package_name_prefix] = prefix
          subject.attributes[:python_package_name_prefix_given?] = true
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
      # Insist on using the defaults for this test, prefix not given and
      # prefix should automatically be based on the python major version
      insist { subject.attributes[:python_package_name_prefix_given?] }.nil?
      subject.input(example_dir)

      prefix = subject.attributes[:python_package_name_prefix]

      # The package name prefix attribute should be set to _something_ by default
      reject { prefix }.nil?

      # XXX: Why is there extra whitespace in these strings?
      #
      # Note: The dependency list should only include entries which are supported by fpm.
      #       python dependencies can have 'environment markers' and most of those markers are
      #       not supported by fpm.
      #       In this test, there are (at time of writing) some python_version markers and fpm doesn't
      #       support those.
      insist { subject.dependencies.sort } == ["#{prefix}-dependency1","#{prefix}-dependency2", "#{prefix}-rtxt-dep4"]
    end

    context "and :python_disable_dependency is set" do
      before :each do
        subject.attributes[:python_disable_dependency] = "Dependency1"
      end

      it "it should exclude the dependency" do
        subject.input(example_dir)
        prefix = subject.attributes[:python_package_name_prefix]
        insist { subject.dependencies.sort } == ["#{prefix}-dependency2", "#{prefix}-rtxt-dep4"]
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
        prefix = subject.attributes[:python_package_name_prefix]
        insist { subject.dependencies.sort } == ["#{prefix}-rtxt-dep1 > 0.1", "#{prefix}-rtxt-dep2 = 0.1", "#{prefix}-rtxt-dep4"]
      end

      it "it should exclude the dependency" do
        subject.attributes[:python_disable_dependency] = "rtxt-dep1"
        subject.input(example_dir)
        prefix = subject.attributes[:python_package_name_prefix]
        insist { subject.dependencies.sort } == ["#{prefix}-rtxt-dep2 = 0.1", "#{prefix}-rtxt-dep4"]
      end
    end

    context "and :python_fix_dependencies? is false" do
      before :each do
        subject.attributes[:python_fix_dependencies?] = false
      end

      it "it should load requirements.txt" do
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["rtxt-dep1 > 0.1", "rtxt-dep2 = 0.1", "rtxt-dep4"]
      end

      it "it should exclude the dependency" do
        subject.attributes[:python_disable_dependency] = "rtxt-dep1"
        subject.input(example_dir)
        insist { subject.dependencies.sort } == ["rtxt-dep2 = 0.1", "rtxt-dep4"]
      end
    end
  end

  context "when input is a name" do
    it "should download from pypi" do
      subject.input("click==8.3.0")
      prefix = subject.attributes[:python_package_name_prefix]

      insist { subject.name } == "#{prefix}-click"
      insist { subject.version } == "8.3.0"
      insist { subject.maintainer } == "Pallets <contact@palletsprojects.com>"
      insist { subject.architecture } == "all"
      insist { subject.dependencies } == [ ]

    end
  end

  context "when given a project containing a pyproject.toml" do
    let (:project) do
      File.expand_path("../../fixtures/python-pyproject.toml/", File.dirname(__FILE__))
    end

    it "should package it correctly" do
      subject.input(project)
      prefix = subject.attributes[:python_package_name_prefix]

      insist { subject.name } == "#{prefix}-example"
      insist { subject.version } == "1.2.3"
      insist { subject.maintainer } == "Captain Fancy <foo@example.com>"
    end

    it "should package it correctly even if the path given is directly to the pyproject.toml" do
      subject.input(File.join(project, "pyproject.toml"))
      prefix = subject.attributes[:python_package_name_prefix]

      insist { subject.name } == "#{prefix}-example"
      insist { subject.version } == "1.2.3"
      insist { subject.maintainer } == "Captain Fancy <foo@example.com>"
    end

  end
end # describe FPM::Package::Python

describe FPM::Package::Python::PythonMetadata do

  context "processing simple examples" do
    let(:text) {
      [ 
        "Metadata-Version: 2.4",
        "Name: hello",
        "Version: 1.0",
      ].join("\n") + "\n"
    }
    subject { described_class.from(text) }

    it "should" do
      insist { subject.name } == "hello"
      insist { subject.version } == "1.0"
    end
  end

  # Use a known METADATA file from a real Python package
  context "when parsing Django 5.2.6's METADATA" do
    let(:text) do
      File.read(File.expand_path("../../fixtures/python/METADATA", File.dirname(__FILE__)))
    end

    expectations = {
      "Metadata-Version" => "2.4",
      "Name" => "Django",
      "Version" => "5.2.6",
      "Summary" => "A high-level Python web framework that encourages rapid development and clean, pragmatic design.",
      "Author-email" => "Django Software Foundation <foundation@djangoproject.com>",
      "License" => "BSD-3-Clause",
    }

    let(:parsed) { described_class.parse(text) }
    let(:headers) { parsed[0] }
    let(:body) { parsed[1] }

    let(:metadata) { described_class.from(text) }

    expectations.each do |field, value|
      it "the #{field} field should be #{value.inspect}" do
        insist { headers[field] } == value
      end
    end

    it "should parse multivalue fields into an array value" do
      insist { headers["Classifier"] }.is_a?(Enumerable)
      insist { headers["Project-URL"] }.is_a?(Enumerable)
      insist { headers["Requires-Dist"] }.is_a?(Enumerable)

      insist { headers["Requires-Dist"] }.include?('asgiref>=3.8.1')
      insist { headers["Requires-Dist"] }.include?('sqlparse>=0.3.1')
      insist { headers["Requires-Dist"] }.include?('tzdata; sys_platform == "win32"')
      insist { headers["Requires-Dist"] }.include?('argon2-cffi>=19.1.0; extra == "argon2"')
      insist { headers["Requires-Dist"] }.include?('bcrypt; extra == "bcrypt"')
    end

    it "should provide correctly parsed values" do
      insist { metadata.name } == "Django"
      insist { metadata.version } == "5.2.6"
      insist { metadata.summary } == "A high-level Python web framework that encourages rapid development and clean, pragmatic design."
      insist { metadata.license } == "BSD-3-Clause"
      insist { metadata.homepage } == "https://www.djangoproject.com/"
    end
  end # parsing Django METADATA
end
