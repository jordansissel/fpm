require "spec_setup"
require 'fileutils'
require "fpm" # local
require "fpm/package/deb" # local
require "fpm/package/dir" # local
require "stud/temporary"
require "English" # for $CHILD_STATUS

describe FPM::Package::Deb do
  # dpkg-deb lets us query deb package files.
  # Comes with debian and ubuntu systems.
  have_dpkg_deb = program_exists?("dpkg-deb")
  if !have_dpkg_deb
    Cabin::Channel.get("rspec") \
      .warn("Skipping some deb tests because 'dpkg-deb' isn't in your PATH")
  end

  have_lintian = program_exists?("lintian")
  if !have_lintian
    Cabin::Channel.get("rspec") \
      .warn("Skipping some deb tests because 'lintian' isn't in your PATH")
  end

  let(:target) { Stud::Temporary.pathname + ".deb" }
  after do
    subject.cleanup
    File.unlink(target) if File.exist?(target)
  end

  describe "#architecture" do
    it "should convert x86_64 to amd64" do
      subject.architecture = "x86_64"
      expect(subject.architecture).to(be == "amd64")
    end

    it "should convert noarch to all" do
      subject.architecture = "noarch"
      expect(subject.architecture).to(be == "all")
    end

    let(:native) do
      if program_exists?("dpkg")
        `dpkg --print-architecture`.chomp
      else
        `uname -m`.chomp
      end
    end

    it "should default to native" do
      # Convert kernel name to debian name
      expected = native == "x86_64" ? "amd64" : native
      expect(subject.architecture).to(be == expected)
    end
  end

  describe "#iteration" do
    it "should default to nil" do
      expect(subject.iteration).to(be_nil)
    end
  end

  describe "#epoch" do
    it "should default to nil" do
      expect(subject.epoch).to(be_nil)
    end
  end

  describe "priority" do
    it "should default to 'extra'" do
      expect(subject.attributes[:deb_priority]).to(be == "extra")
    end
  end

  describe "use-file-permissions" do
    it "should be nil by default" do
      expect(subject.attributes[:deb_use_file_permissions?]).to(be_nil)
    end
  end

  describe "#to_s" do
    before do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = "100"
      subject.epoch = "5"
    end

    it "should have a default output usable as a filename" do
      # This is the default filename I see commonly produced by debuild
      insist { subject.to_s } == "name_123-100_all.deb"
    end

    context "when iteration is nil" do
      before do
        subject.iteration = nil
      end

      it "should not include iteration if it is nil" do
        # This is the default filename I see commonly produced by debuild
        expect(subject.to_s).to(be == "name_123_all.deb")
      end
    end
  end

  context "supporting debian policy hacks" do
    before do
      subject.name = "Capitalized_Name_With_Underscores"
    end

    it "should lowercase the package name" do
      expect(subject.name).to(be == subject.name.downcase)
    end

    it "should replace underscores with dashes in the package name" do
      expect(subject.name).not_to(be_include("_"))
    end

    it "should replace spaces with dashes in the package name" do
      expect(subject.name).not_to(be_include(" "))
    end
  end

  describe "#output" do
    let(:original) { FPM::Package::Deb.new }
    let(:input) { FPM::Package::Deb.new }

    before do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      # The target file must not exist.

      original.name = "name"
      original.version = "123"
      original.iteration = "100"
      original.epoch = "5"
      original.architecture = "all"
      original.dependencies << "something > 10"
      original.dependencies << "hello >= 20"
      original.provides << "#{original.name} = #{original.version}"

      # Test to cover PR#591 (fix provides names)
      original.provides << "Some-SILLY_name"

      original.conflicts = ["foo < 123"]
      original.attributes[:deb_breaks] = ["baz < 123"]

      original.attributes[:deb_build_depends_given?] = true
      original.attributes[:deb_build_depends] ||= []
      original.attributes[:deb_build_depends] << 'something-else > 0.0.0'
      original.attributes[:deb_build_depends] << 'something-else < 1.0.0'

      original.attributes[:deb_priority] = "fizzle"
      original.attributes[:deb_field_given?] = true
      original.attributes[:deb_field] = { "foo" => "bar" }

      original.attributes[:deb_meta_files] = %w(meta_test triggers).map do |fn|
        File.expand_path("../../../fixtures/deb/#{fn}", __FILE__)
      end

      original.attributes[:deb_interest] = ['asdf', 'hjkl']
      original.attributes[:deb_activate] = ['qwer', 'uiop']

      original.output(target)
      input.input(target)
    end

    after do
      original.cleanup
      input.cleanup
    end # after

    context "when the deb's control section is extracted" do
      let(:control_dir) { Stud::Temporary.directory }
      before do
        system("ar p '#{target}' control.tar.gz | tar -zx -C '#{control_dir}'") 
        raise "couldn't extract test deb" unless $CHILD_STATUS.success?
      end

      it "should have the requested meta file in the control archive" do
        File.open(File.join(control_dir, 'meta_test')) do |f|
          insist { f.read.chomp } == "asdf"
        end
      end

      it "should have the requested triggers in the triggers file" do
        triggers = File.open(File.join(control_dir, 'triggers')) do |f|
          f.read
        end
        reject { triggers =~ /^interest from-meta-file$/ }.nil?
        reject { triggers =~ /^interest asdf$/ }.nil?
        reject { triggers =~ /^interest hjkl$/ }.nil?
        reject { triggers =~ /^activate qwer$/ }.nil?
        reject { triggers =~ /^activate uiop$/ }.nil?
        insist { triggers[-1] } == "\n"
      end

      after do
        FileUtils.rm_rf(control_dir)
      end
    end

    context "package attributes" do
      it "should have the correct name" do
        insist { input.name } == original.name
      end

      it "should have the correct version" do
        insist { input.version } == original.version
      end

      it "should have the correct iteration" do
        insist { input.iteration } == original.iteration
      end

      it "should have the correct epoch" do
        insist { input.epoch } == original.epoch
      end

      it "should have the correct dependencies" do
        original.dependencies.each do |dep|
          insist { input.dependencies }.include?(dep)
        end
      end

      it "should ignore versions and conditions in 'provides' (#280)" do
        # Provides is an array because rpm supports multiple 'provides'
        insist { input.provides }.include?(original.name)
      end

      it "should fix capitalization and underscores-to-dashes (#591)" do
        insist { input.provides }.include?("some-silly-name")
      end
    end # package attributes

    # This section mainly just verifies that 'dpkg-deb' can parse the package.
    context "when read with dpkg", :if => have_dpkg_deb do
      def dpkg_field(field)
        return `dpkg-deb -f #{target} #{field}`.chomp
      end # def dpkg_field

      it "should have the correct name" do
        insist { dpkg_field("Package") } == original.name
      end

      it "should have the correct 'epoch:version-iteration'" do
        insist { dpkg_field("Version") } == original.to_s("EPOCH:VERSION-ITERATION")
      end

      it "should have the correct priority" do
        insist { dpkg_field("Priority") } == original.attributes[:deb_priority]
      end

      it "should have the correct dependency list" do
        # 'something > 10' should convert to 'something (>> 10)', etc.
        insist { dpkg_field("Depends") } == "something (>> 10), hello (>= 20)"
      end

      it "should have the correct build dependency list" do
        insist { dpkg_field("Build-Depends") } == "something-else (>> 0.0.0), something-else (<< 1.0.0)"
      end

      it "should have a custom field 'foo: bar'" do
        insist { dpkg_field("foo") } == "bar"
      end

      it "should have the correct Conflicts" do
        insist { dpkg_field("Conflicts") } == "foo (<< 123)"
      end

      it "should have the correct Breaks" do
        insist { dpkg_field("Breaks") } == "baz (<< 123)"
      end
    end
  end # #output

  describe "#output with no depends" do
    let(:original) { FPM::Package::Deb.new }
    let(:input) { FPM::Package::Deb.new }

    before do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.

      original.name = "name"
      original.version = "123"
      original.iteration = "100"
      original.epoch = "5"
      original.architecture = "all"
      original.dependencies << "something > 10"
      original.dependencies << "hello >= 20"
      original.attributes[:no_depends?] = true
      original.output(target)
      input.input(target)
    end

    after do
      original.cleanup
      input.cleanup
    end # after

    it "should have no dependencies" do
      insist { input.dependencies }.empty?
    end
  end # #output with no dependencies

  describe "#tar_flags" do
    let(:package) { FPM::Package::Deb.new }

    before :each do
      package.name = "name"
    end

    after :each do
      package.cleanup
    end # after

    it "should set the user for the package's data files" do
      package.attributes[:deb_user] = "nobody"
      # output a package so that @data_tar_flags is computed
      expect(package.data_tar_flags).to(be == ["--owner", "nobody", "--numeric-owner", "--group", "0"])
    end

    it "should set the group for the package's data files" do
      package.attributes[:deb_group] = "nogroup"
      # output a package so that @data_tar_flags is computed
      expect(package.data_tar_flags).to(be == ["--numeric-owner", "--owner", "0", "--group", "nogroup"])
    end

    it "should not set the user or group for the package's data files if :deb_use_file_permissions? is not nil" do
      package.attributes[:deb_use_file_permissions?] = true
      # output a package so that @data_tar_flags is computed
      package.output(target)
      expect(package.data_tar_flags).to(be == [])
    end
  end # #tar_flags

  describe "#output with lintian" do
    let(:staging_path) { Stud::Temporary.directory }
    before do
      # TODO(sissel): Refactor this to use factory pattern instead of fixture?
      FileUtils.cp_r(Dir['spec/fixtures/deb/staging/*'], staging_path)

      subject.name = "name"
      subject.version = "0.0.1"
      subject.maintainer = "Jordan Sissel <jls@semicomplete.com>"
      subject.description = "Test package\nExtended description."
      subject.attributes[:deb_user] = "root"
      subject.attributes[:deb_group] = "root"

      subject.instance_variable_set(:@config_files, ["/etc/init.d/test"])
      subject.instance_variable_set(:@staging_path, staging_path)

      subject.output(target)
    end

    after do
      FileUtils.rm_r staging_path if File.exist? staging_path
    end # after

    context "when run against lintian", :if => have_lintian do
      lintian_errors_to_ignore = [
        "no-copyright-file",
        "init.d-script-missing-lsb-section",
        "non-standard-file-permissions-for-etc-init.d-script"
      ]

      it "should return no errors" do
        lintian_output = `lintian #{target} --suppress-tags #{lintian_errors_to_ignore.join(",")}`
        expect($CHILD_STATUS).to eq(0), lintian_output
      end
    end
  end
end # describe FPM::Package::Deb
