require "spec_setup"
require "fpm" # local
require "fpm/package/virtualenv" # local
require "find" # stdlib

def virtualenv_usable?
  return program_exists?("virtualenv") && program_exists?("virtualenv-tools")
end

if !virtualenv_usable?
  Cabin::Channel.get("rspec").warn("Skipping python virtualenv tests because " \
    "no virtualenv/tools bin on your path")
end

describe FPM::Package::Virtualenv, :if => virtualenv_usable? do
  before do
    skip("virtualenv and/or virtualenv-tools programs not found") unless virtualenv_usable?
  end

  after :each do
    subject.cleanup
  end

  context "without a version on the input" do
    it "requires that the version be passed separately" do
      # this failed before I got here
      subject.version = "8.1.2"
      subject.input("pip")
    end
  end

  context "with a version on the input" do
    it "requires that the version be passed separately" do
      subject.input("pip==8.1.2")

      insist { subject.version } == "8.1.2"
      insist { subject.name } == "virtualenv-pip"

      activate_path = File.join(subject.build_path, '/usr/share/python/pip/bin/activate')

      expect(File.exist?(activate_path)).to(be_truthy)
    end

    it "can override the version specified on the input" do
      subject.version = "1.2.3"
      subject.input("pip==8.1.2")

      insist { subject.version } == "1.2.3"
      insist { subject.name } == "virtualenv-pip"
    end

    context "with a package name supplied" do

      before do
        subject.name = "foo"
      end

      it "will prepend the default prefix" do
        subject.input("pip==8.1.2")

        insist { subject.name } == "virtualenv-foo"
      end

      it "will prepend a non default prefix" do
        subject.attributes[:virtualenv_package_name_prefix] = 'bar'
        subject.input("pip==8.1.2")

        insist { subject.name } == "bar-foo"
      end

      it "will not prepend a prefix if --fix-name is false" do
        subject.attributes[:virtualenv_fix_name?] = false
        subject.input("pip==8.1.2")

        insist { subject.name } == "foo"
      end
    end
  end

  context "with an alternate install path" do
    it "installs in to the alternate directory" do
      # it seems odd that you can't control the name of the directory under here...
      subject.attributes[:virtualenv_install_location] = '/opt/foo'

      subject.input("pip==8.1.2")

      activate_path = File.join(subject.build_path, '/opt/foo/pip/bin/activate')
      expect(File.exist?(activate_path)).to(be_truthy)
    end
  end

  context "with other files dir" do
    it "includes the other files in the package" do
      subject.attributes[:virtualenv_other_files_dir] =  File.expand_path("../../fixtures/python/", File.dirname(__FILE__))
      subject.input("pip==8.1.2")

      activate_path = File.join(subject.build_path, '/usr/share/python/pip/bin/activate')
      expect(File.exist?(activate_path)).to(be_truthy)

      egg_path =  File.join(subject.build_path, '/setup.py')
      expect(File.exist?(egg_path)).to(be_truthy)
    end
  end

  context "input is a requirements.txt file" do

    before :each do
      subject.attributes[:virtualenv_requirements?] = true
    end

    let :fixtures_dir do
      File.expand_path("../../fixtures/virtualenv/", File.dirname(__FILE__))
    end

    context "default use" do

      it "creates the virtualenv, using the parent dir as the package name" do
        subject.input(File.join(fixtures_dir, 'requirements.txt'))

        activate_path = File.join(subject.build_path, '/usr/share/python/virtualenv/bin/activate')
        expect(File.exist?(activate_path)).to(be_truthy)
        expect(subject.name).to eq("virtualenv-virtualenv")
      end
    end

    context "with --name" do
      it "uses the supplied argument over the parent dir " do
        subject.name = 'foo'
        subject.input(File.join(fixtures_dir, 'requirements.txt'))
        activate_path = File.join(subject.build_path, '/usr/share/python/virtualenv/bin/activate')

        expect(File.exist?(activate_path)).to(be_truthy)

        expect(subject.name).to eq("virtualenv-foo")
      end
    end
  end

  context "new --prefix behaviour" do
    it "--prefix puts virtualenv under the prefix" do
      subject.attributes[:prefix] = '/opt/foo'
      subject.input('absolute')

      activate_path = File.join(subject.staging_path, '/opt/foo/bin/activate')

      expect(File.exist?(activate_path)).to(be_truthy)
    end

    it "takes precedence over other folder options" do
      subject.attributes[:prefix] = '/opt/foo'
      subject.attributes[:install_location] = '/usr/local/foo'
      subject.input('absolute')

      activate_path = File.join(subject.staging_path, '/opt/foo/bin/activate')

      expect(File.exist?(activate_path)).to(be_truthy)
    end
  end
end
