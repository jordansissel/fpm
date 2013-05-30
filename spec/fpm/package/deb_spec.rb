require "spec_setup"
require "fpm" # local
require "fpm/package/deb" # local
require "fpm/package/dir" # local

describe FPM::Package::Deb do
  # dpkg-deb lets us query deb package files. 
  # Comes with debian and ubuntu systems.
  have_dpkg_deb = program_in_path?("dpkg-deb")
  if !have_dpkg_deb
    Cabin::Channel.get("rspec") \
      .warn("Skipping some deb tests because 'dpkg-deb' isn't in your PATH")
  end

  after :each do
    subject.cleanup
  end

  describe "#architecture" do
    it "should convert x86_64 to amd64" do
      subject.architecture = "x86_64"
      insist { subject.architecture } == "amd64"
    end

    it "should convert noarch to all" do
      subject.architecture = "noarch"
      insist { subject.architecture } == "all"
    end

    it "should default to native" do
      expected = ""
      if program_in_path?("dpkg")
        expected = %x{dpkg --print-architecture}.chomp
      end

      if expected.empty?
        # dpkg was missing, failed, or emitted nothing.
        expected = %x{uname -m}.chomp
      end

      # Convert kernel name to debian name
      expected = "amd64" if expected == "x86_64"
      insist { subject.architecture } == expected
    end
  end

  describe "#iteration" do
    it "should default to nil" do
      insist { subject.iteration }.nil?
    end
  end

  describe "#epoch" do
    it "should default to nil" do
      insist { subject.epoch }.nil?
    end
  end

  describe "priority" do
    it "should default to 'extra'" do
      insist { subject.attributes[:deb_priority] } == "extra"
    end
  end

  describe "#to_s" do
    it "should have a default output usable as a filename" do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = "100"
      subject.epoch = "5"

      # This is the default filename I see commonly produced by debuild
      insist { subject.to_s } == "name_123-100_all.deb"
    end

    it "should not include iteration if it is nil" do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = nil
      subject.epoch = "5"

      # This is the default filename I see commonly produced by debuild
      insist { subject.to_s } == "name_123_all.deb"
    end
  end

  context "supporting debian policy hacks" do
    subject do
      package = FPM::Package::Deb.new
      package.name = "Capitalized_Name_With_Underscores"
      package
    end

    it "should lowercase the package name" do
      insist { subject.name } == subject.name.downcase
    end

    it "should replace underscores with dashes in the package name" do
      reject { subject.name }.include?("_")
    end
  end

  describe "#output" do 
    before :all do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      tmpfile = Tempfile.new("fpm-test-deb")
      @target = tmpfile.path
      # The target file must not exist.
      tmpfile.unlink

      @original = FPM::Package::Deb.new
      @original.name = "name"
      @original.version = "123"
      @original.iteration = "100"
      @original.epoch = "5"
      @original.architecture = "all"
      @original.dependencies << "something > 10"
      @original.dependencies << "hello >= 20"
      @original.provides = "#{@original.name} = #{@original.version}"

      @original.conflicts = ["foo < 123"]
      @original.attributes[:deb_breaks] = ["baz < 123"]

      @original.attributes[:deb_build_depends_given?] = true
      @original.attributes[:deb_build_depends] ||= []
      @original.attributes[:deb_build_depends] << 'something-else > 0.0.0'
      @original.attributes[:deb_build_depends] << 'something-else < 1.0.0'

      @original.attributes[:deb_priority] = "fizzle"
      @original.attributes[:deb_field_given?] = true
      @original.attributes[:deb_field] = { "foo" => "bar" }
      @original.output(@target)

      @input = FPM::Package::Deb.new
      @input.input(@target)
    end

    after :all do
      @original.cleanup
      @input.cleanup
    end # after

    context "package attributes" do
      it "should have the correct name" do
        insist { @input.name } == @original.name
      end

      it "should have the correct version" do
        insist { @input.version } == @original.version
      end

      it "should have the correct iteration" do
        insist { @input.iteration } == @original.iteration
      end

      it "should have the correct epoch" do
        insist { @input.epoch } == @original.epoch
      end

      it "should have the correct dependencies" do
        @original.dependencies.each do |dep|
          insist { @input.dependencies }.include?(dep)
        end
      end

      it "should ignore versions and conditions in 'provides' (#280)" do
        # Provides is an array because rpm supports multiple 'provides'
        insist { @input.provides } == [ @original.name ]
      end
    end # package attributes

    # This section mainly just verifies that 'dpkg-deb' can parse the package.
    context "when read with dpkg", :if => have_dpkg_deb do
      def dpkg_field(field)
        return %x{dpkg-deb -f #{@target} #{field}}.chomp
      end # def dpkg_field

      it "should have the correct name" do
        insist { dpkg_field("Package") } == @original.name
      end

      it "should have the correct 'epoch:version-iteration'" do
        insist { dpkg_field("Version") } == @original.to_s("EPOCH:VERSION-ITERATION")
      end

      it "should have the correct priority" do
        insist { dpkg_field("Priority") } == @original.attributes[:deb_priority]
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
    before :all do
      # output a package, use it as the input, set the subject to that input
      # package. This helps ensure that we can write and read packages
      # properly.
      tmpfile = Tempfile.new("fpm-test-deb")
      @target = tmpfile.path
      # The target file must not exist.
      tmpfile.unlink

      @original = FPM::Package::Deb.new
      @original.name = "name"
      @original.version = "123"
      @original.iteration = "100"
      @original.epoch = "5"
      @original.architecture = "all"
      @original.dependencies << "something > 10"
      @original.dependencies << "hello >= 20"
      @original.attributes[:no_depends?] = true
      @original.output(@target)

      @input = FPM::Package::Deb.new
      @input.input(@target)
    end

    after :all do
      @original.cleanup
      @input.cleanup
    end # after

    it "should have no dependencies" do
      insist { @input.dependencies }.empty?
    end
  end # #output with no dependencies
end # describe FPM::Package::Deb
