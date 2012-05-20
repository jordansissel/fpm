require "spec_setup"
require "fpm" # local
require "fpm/package/rpm" # local
require "fpm/package/dir" # local
require "arr-pm/file" # gem 'arr-pm'

if !program_in_path?("rpmbuild")
  Cabin::Channel.get("rspec") \
    .warn("Skipping RPM#output tests because 'rpmbuild' isn't in your PATH")
end

describe FPM::Package::RPM do
  after :each do
    subject.cleanup
  end

  describe "#architecture" do
    it "should convert amd64 to x86_64" do
      subject.architecture = "amd64"
      insist { subject.architecture } == "x86_64"
    end

    it "should convert 'all' to 'noarch'" do
      subject.architecture = "all"
      insist { subject.architecture } == "noarch"
    end

    it "should default to native" do
      expected = %x{uname -m}.chomp
      insist { subject.instance_eval { @architecture } } == "native"
      insist { subject.architecture } == expected
    end
  end

  describe "#iteration" do
    it "should default to 1" do
      insist { subject.iteration } == 1
    end
  end

  describe "#epoch" do
    it "should default to nil" do
      insist { subject.epoch }.nil?
    end
  end
  
  describe "#to_s" do
    it "should have a default output usable as a filename" do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = "100"
      subject.epoch = "5"

      # This is the default filename I see commonly output by rpmbuild
      insist { subject.to_s } == "name-123-100.noarch.rpm"
    end
  end

  describe "#templating" do
    context "default user and group" do
      before :all do

        # set the list of files for this RPM
        def subject.files; [__FILE__]; end
        def subject.rpmspec; @rpmspec; end
        def subject.render_template; @rpmspec = template("rpm.erb").result(binding); end
        subject.render_template
      end

      after :all do
        subject.cleanup
      end

      it "should set the user and group of each file in the RPM" do
        subject.rpmspec.should include('%defattr(-,root,root,-')
      end
    end # context

    context "non-default user and group" do
      before :all do
        subject.attributes[:rpm_user] = "some_user"
        subject.attributes[:rpm_group] = "some_group"

        # set the list of files for this RPM
        def subject.files; [__FILE__]; end
        def subject.rpmspec; @rpmspec; end
        def subject.render_template; @rpmspec = template("rpm.erb").result(binding); end
        subject.render_template
      end

      after :all do
        subject.cleanup
      end

      it "should set the user and group of each file in the RPM" do
        subject.rpmspec.should include('%defattr(-,some_user,some_group,-')
      end
    end # context
  end

  describe "#output", :if => program_in_path?("rpmbuild") do
    context "package attributes" do
      before :all do
        @target = Tempfile.new("fpm-test-rpm")
        subject.name = "name"
        subject.version = "123"
        subject.architecture = "all"
        subject.iteration = "100"
        subject.epoch = "5"
        subject.dependencies << "something > 10"
        subject.dependencies << "hello >= 20"
        subject.conflicts << "bad < 2"
        subject.provides << "bacon = 1.0"

        # TODO(sissel): This api sucks, yo.
        subject.scripts[:before_install] = "example before_install"
        subject.scripts[:after_install] = "example after_install"
        subject.scripts[:before_remove] = "example before_remove"
        subject.scripts[:after_remove] = "example after_remove"

        # Write the rpm out
        subject.output(@target.path)

        # Read the rpm
        @rpm = ::RPM::File.new(@target.path)

        @rpmtags = {}
        @rpm.header.tags.each do |tag|
          @rpmtags[tag.tag] = tag.value
        end
      end

      after :all do
        subject.cleanup
        @target.close
        @target.delete
      end # after

      it "should have the correct name" do
        insist { @rpmtags[:name] } == subject.name
      end

      it "should have the correct version" do
        insist { @rpmtags[:version] } == subject.version
      end

      it "should have the correct iteration" do
        insist { @rpmtags[:release] } == subject.iteration
      end

      it "should have the correct epoch" do
        insist { @rpmtags[:epoch].first.to_s } == subject.epoch
      end

      it "should output a package with the correct dependencies" do
        # @rpm.requires is an array of [name, op, requires] elements
        # fpm uses strings here, so convert.
        requires = @rpm.requires.collect { |a| a.join(" ") }

        subject.dependencies.each do |dep|
          insist { requires }.include?(dep)
        end
      end

      it "should output a package with the correct conflicts" do
        # @rpm.requires is an array of [name, op, requires] elements
        # fpm uses strings here, so convert.
        conflicts = @rpm.conflicts.collect { |a| a.join(" ") }

        subject.conflicts.each do |dep|
          insist { conflicts }.include?(dep)
        end
      end

      it "should output a package with the correct provides" do
        # @rpm.requires is an array of [name, op, requires] elements
        # fpm uses strings here, so convert.
        provides = @rpm.provides.collect { |a| a.join(" ") }

        subject.provides.each do |dep|
          insist { provides }.include?(dep)
        end
      end

      it "should have the correct 'preun' script" do
        insist { @rpm.tags[:preun] } == "example before_remove"
        insist { @rpm.tags[:preunprog] } == "/bin/sh"
      end

      it "should have the correct 'postun' script" do
        insist { @rpm.tags[:postun] } == "example after_remove"
        insist { @rpm.tags[:postunprog] } == "/bin/sh"
      end

      it "should have the correct 'prein' script" do
        insist { @rpm.tags[:prein] } == "example before_install"
        insist { @rpm.tags[:preinprog] } == "/bin/sh"
      end

      it "should have the correct 'postin' script" do
        insist { @rpm.tags[:postin] } == "example after_install"
        insist { @rpm.tags[:postinprog] } == "/bin/sh"
      end

      it "should use md5/gzip by default" do
        insist { @rpmtags[:payloadcompressor] } == "gzip"

        # For whatever reason, the 'filedigestalgo' tag is an array of numbers.
        # I only ever see one element in this array, so just do value.first
        # 
        # Even though you can specify a file digest algorithm of md5, not
        # specifying one at all is also valid in the RPM file itself,
        # and not having one at all means md5. So accept 'nil' or the digest
        # identifier for md5 (1).
        insist { [nil, FPM::Package::RPM::DIGEST_ALGORITHM_MAP["md5"]] } \
          .include?((@rpmtags[:filedigestalgo].first rescue nil))
      end
    end # package attributes

    describe "regressions should not occur" do
      before :each do
        @target = Tempfile.new("fpm-test-rpm")
        subject.name = "name"
        subject.version = "123"
        subject.iteration = "100"
        subject.epoch = "5"
      end

      after :each do
        subject.cleanup
        @target.close
        @target.delete
      end # after

      it "should permit spaces in filenames (issue #164)" do
        File.write(subject.staging_path("file with space"), "Hello")

        # This will raise an exception if rpmbuild fails.
        subject.output(@target.path)
      end

      it "should permit brackets in filenames (issue #202)" do
        File.write(subject.staging_path("file[with]bracket"), "Hello")

        # This will raise an exception if rpmbuild fails.
        subject.output(@target.path)
      end

      it "should permit asterisks in filenames (issue #202)" do
        File.write(subject.staging_path("file*asterisk"), "Hello")

        # This will raise an exception if rpmbuild fails.
        subject.output(@target.path)
      end
    end # regression stuff
  end # #output

  describe "#output with digest and compression settings", :if => program_in_path?("rpmbuild") do
    context "bzip2/sha1" do
      before :all do
        @target = Tempfile.new("fpm-test-rpm")
        subject.name = "name"
        subject.version = "123"
        subject.architecture = "all"
        subject.iteration = "100"
        subject.epoch = "5"
        subject.attributes[:rpm_compression] = "bzip2"
        subject.attributes[:rpm_digest] = "sha1"

        # Write the rpm out
        subject.output(@target.path)

        # Read the rpm
        @rpm = ::RPM::File.new(@target.path)

        @rpmtags = {}
        @rpm.header.tags.each do |tag|
          @rpmtags[tag.tag] = tag.value
        end
      end

      after :all do
        subject.cleanup
        @target.close
        @target.delete
      end # after

      it "should have the compressor and digest algorithm listed" do
        insist { @rpmtags[:payloadcompressor] } == "bzip2"

        # For whatever reason, the 'filedigestalgo' tag is an array of numbers.
        # I only ever see one element in this array, so just do value.first
        insist { @rpmtags[:filedigestalgo].first } \
          == FPM::Package::RPM::DIGEST_ALGORITHM_MAP["sha1"]
      end
    end # bzip2/sha1
  end # #output with digest/compression settings
end # describe FPM::Package::RPM
