require "spec_setup"
require "fpm" # local
require "fpm/package/rpm" # local
require "fpm/package/dir" # local
require "arr-pm/file" # gem 'arr-pm'
require "stud/temporary" # gem 'stud'

if !program_exists?("rpmbuild")
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

    it "should convert arm64 to aarch64" do
      subject.architecture = "arm64"
      expect(subject.architecture).to(be == "aarch64")
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

  describe "#summary" do
    it "should default to description" do
      expected = subject.description
      insist { subject.summary } == expected
    end

    it "should return description override" do
      subject.attributes[:rpm_summary] = "a summary"
      expected = subject.description
      insist { subject.summary } != expected
    end
  end

  describe "#epoch" do
    it "should default to empty" do
      insist { subject.epoch.to_s } == ""
    end
    it "should cope with it being zero" do
      subject.epoch = 0
      insist { subject.epoch.to_s } == "0"
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

    it "should include the dist when specified" do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "all"
      subject.iteration = "100"
      subject.epoch = "5"

      insist { subject.to_s } == "name-123-100.noarch.rpm"
      subject.attributes[:rpm_dist] = "el6"
      insist { subject.to_s } == "name-123-100.el6.noarch.rpm"
    end
  end


  describe "#templating" do
    context "default user and group" do
      before :each do
        FileUtils.mkdir_p(subject.staging_path(File.dirname(__FILE__)))
        FileUtils.cp(__FILE__, subject.staging_path(__FILE__))

        # set the list of files for this RPM
        def subject.files; [__FILE__]; end
        def subject.rpmspec; @rpmspec; end
        def subject.render_template; @rpmspec = template("rpm.erb").result(binding); end
        subject.render_template
      end

      after :each do
        subject.cleanup
      end

      it "should set the user and group of each file in the RPM" do
        expect(subject.rpmspec).to include('%defattr(-,root,root,-')
      end
    end # context

    context "non-default user and group" do
      before :each do
        subject.attributes[:rpm_user] = "some_user"
        subject.attributes[:rpm_group] = "some_group"

        FileUtils.mkdir_p(subject.staging_path(File.dirname(__FILE__)))
        FileUtils.cp(__FILE__, subject.staging_path(__FILE__))

        # set the list of files for this RPM
        def subject.files; [__FILE__]; end
        def subject.rpmspec; @rpmspec; end
        def subject.render_template; @rpmspec = template("rpm.erb").result(binding); end
        subject.render_template
      end

      after :each do
        subject.cleanup
      end

      it "should set the user and group of each file in the RPM" do
        expect(subject.rpmspec).to include('%defattr(-,some_user,some_group,-')
      end
    end # context
  end

  describe "#output" do
    before do
      skip("Missing rpmbuild program") unless program_exists?("rpmbuild")
    end

    context "architecture" do
      it "can be basically anything" do
        subject.name = "example"
        subject.architecture = "fancypants"
        subject.version = "1.0"
        target = Stud::Temporary.pathname

        # Should not fail.
        subject.output(target)

        # Verify the arch tag.
        rpm = ::RPM::File.new(target)
        insist { rpm.tags[:arch] } == subject.architecture

        File.unlink(target)
      end
    end

    context "with slight corrections" do
      context "on the version attribute" do
        it "should replace dash(-) with underscore(_)" do
          subject.version = "123-456"
          insist { subject.version } == "123_456"
        end
      end
      context "on the iteration attribute" do
        # Found in https://github.com/electron-userland/electron-builder/issues/5976
        it "should replace dash(-) with underscore(_)" do
          subject.iteration = "123-456"
          insist { subject.iteration } == "123_456"
        end
      end
    end
    context "package attributes" do
      before :each do
        @target = Stud::Temporary.pathname
        subject.name = "name"
        subject.version = "123"
        subject.architecture = "all"
        subject.iteration = "100"
        subject.epoch = "5"
        subject.dependencies << "something > 10"
        subject.dependencies << "hello >= 20"
        subject.conflicts << "bad < 2"
        subject.attributes[:rpm_os] = "fancypants"
        subject.attributes[:rpm_summary] = "fancypants"

        # Make sure multi-line licenses are hacked to work in rpm (#252)
        subject.license = "this\nis\nan\example"
        subject.provides << "bacon = 1.0"

        # TODO(sissel): This api sucks, yo.
        subject.scripts[:before_install] = "example before_install"
        subject.scripts[:after_install] = "example after_install"
        subject.scripts[:before_remove] = "example before_remove"
        subject.scripts[:after_remove] = "example after_remove"
        subject.scripts[:rpm_verifyscript] = "example rpm_verifyscript"
        subject.scripts[:rpm_posttrans] = "example rpm_posttrans"
        subject.scripts[:rpm_pretrans] = "example rpm_pretrans"


        # Test for triggers #626
        subject.attributes[:rpm_trigger_before_install] = [["test","#!/bin/sh\necho before_install trigger executed\n"]]
        subject.attributes[:rpm_trigger_after_install] = [["test","#!/bin/sh\necho after_install trigger executed\n"]]
        subject.attributes[:rpm_trigger_before_uninstall] = [["test","#!/bin/sh\necho before_uninstall trigger executed\n"]]
        subject.attributes[:rpm_trigger_after_target_uninstall] = [["test","#!/bin/sh\necho after_target_uninstall trigger executed\n"]]

        # Write the rpm out
        subject.output(@target)

        # Read the rpm
        @rpm = ::RPM::File.new(@target)

        @rpmtags = {}
        @rpm.header.tags.each do |tag|
          @rpmtags[tag.tag] = tag.value
        end
      end # before :each

      after :each do
        subject.cleanup
        File.delete(@target)
      end # after :each

      it "should have the correct name" do
        insist { @rpmtags[:name] } == subject.name
      end

      it "should obey the os attribute" do
        insist { @rpmtags[:os] } == subject.attributes[:rpm_os]
      end

      it "should have a different summary and description" do
        insist { @rpmtags[:summary] } == subject.summary
        insist { @rpmtags[:summary] } != subject.description
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

      it "should replace newlines with spaces in the license field (issue#252)" do
        insist { @rpm.tags[:license] } == subject.license.split("\n").join(" ")
      end

      it "should have the correct 'preun' script" do
        insist { @rpm.tags[:preun] } == "example before_remove"
        insist { @rpm.tags[:preunprog] } == "/bin/sh"
      end

      it "should have the correct 'postun' script" do
        insist { @rpm.tags[:postun] } == "example after_remove"
        insist { @rpm.tags[:postunprog] } == "/bin/sh"
      end

      it "should have the correct 'verify' script" do
        insist { @rpm.tags[:verifyscript] } == "example rpm_verifyscript"
        insist { @rpm.tags[:verifyscriptprog] } == "/bin/sh"
      end

      it "should have the correct 'pretrans' script" do
        insist { @rpm.tags[:pretrans] } == "example rpm_pretrans"
        insist { @rpm.tags[:pretransprog] } == "/bin/sh"
      end

      it "should have the correct 'posttrans' script" do
        insist { @rpm.tags[:posttrans] } == "example rpm_posttrans"
        insist { @rpm.tags[:posttransprog] } == "/bin/sh"
      end

      it "should have the correct 'prein' script" do
        insist { @rpm.tags[:prein] } == "example before_install"
        insist { @rpm.tags[:preinprog] } == "/bin/sh"
      end

      it "should have the correct 'postin' script" do
        insist { @rpm.tags[:postin] } == "example after_install"
        insist { @rpm.tags[:postinprog] } == "/bin/sh"
      end

      it "should have the correct 'before_install' trigger script" do
        insist { @rpm.tags[:triggername][0] } == "test"
        insist { @rpm.tags[:triggerversion][0] } == ""
        # This specific check is broken in newer versions of rpm/rpmbuild? -Jordan
        #insist { @rpm.tags[:triggerflags][0] & (1 << 25)} == ( 1 << 25) # See FPM::Package::RPM#rpm_get_trigger_type
        #insist { @rpm.tags[:triggerindex][0] } == 0
        insist { @rpm.tags[:triggerscriptprog][0] } == "/bin/sh"
        insist { @rpm.tags[:triggerscripts][0] } == "#!/bin/sh\necho before_install trigger executed"
      end

      it "should have the correct 'after_install' trigger script" do
        insist { @rpm.tags[:triggername][1] } == "test"
        insist { @rpm.tags[:triggerversion][1] } == ""
        # This specific check is broken in newer versions of rpm/rpmbuild? -Jordan
        #insist { @rpm.tags[:triggerflags][1] & (1 << 16)} == ( 1 << 16) # See FPM::Package::RPM#rpm_get_trigger_type
        #insist { @rpm.tags[:triggerindex][1] } == 1
        insist { @rpm.tags[:triggerscriptprog][1] } == "/bin/sh"
        insist { @rpm.tags[:triggerscripts][1] } == "#!/bin/sh\necho after_install trigger executed"
      end

      it "should have the correct 'before_uninstall' trigger script" do
        insist { @rpm.tags[:triggername][2] } == "test"
        insist { @rpm.tags[:triggerversion][2] } == ""
        # This specific check is broken in newer versions of rpm/rpmbuild? -Jordan
        #insist { @rpm.tags[:triggerflags][2] & (1 << 17)} == ( 1 << 17) # See FPM::Package::RPM#rpm_get_trigger_type
        #insist { @rpm.tags[:triggerindex][2] } == 2
        insist { @rpm.tags[:triggerscriptprog][2] } == "/bin/sh"
        insist { @rpm.tags[:triggerscripts][2] } == "#!/bin/sh\necho before_uninstall trigger executed"
      end

      it "should have the correct 'after_target_uninstall' trigger script" do
        insist { @rpm.tags[:triggername][3] } == "test"
        insist { @rpm.tags[:triggerversion][3] } == ""
        # This specific check is broken in newer versions of rpm/rpmbuild? -Jordan
        #insist { @rpm.tags[:triggerflags][3] & (1 << 18)} == ( 1 << 18) # See FPM::Package::RPM#rpm_get_trigger_type
        #insist { @rpm.tags[:triggerindex][3] } == 3
        insist { @rpm.tags[:triggerscriptprog][3] } == "/bin/sh"
        insist { @rpm.tags[:triggerscripts][3] } == "#!/bin/sh\necho after_target_uninstall trigger executed"
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

    context "package default attributes" do
      before :each do
        @target = Stud::Temporary.pathname
        subject.name = "name"
        subject.version = "123"
        # Write the rpm out
        subject.output(@target)

        # Read the rpm
        @rpm = ::RPM::File.new(@target)

        @rpmtags = {}
        @rpm.header.tags.each do |tag|
          @rpmtags[tag.tag] = tag.value
        end
      end # before :each

      after :each do
        subject.cleanup
        File.delete(@target)
      end # after :each

      it "should have the correct name" do
        insist { @rpmtags[:name] } == subject.name
      end

      # I don't know the 'os' values for any other OS.
      it "should have a default OS value" do
        os = `uname -s`.chomp.downcase

        # The 'os' tag will be set to \x01 if the package 'target'
        # was set incorrectly.
        reject { @rpmtags[:os] } == "\x01"

        insist { @rpmtags[:os] } == os
        insist { `rpm -q --qf '%{OS}' -p #{@target}`.chomp } == os
      end

      it "should have the correct version" do
        insist { @rpmtags[:version] } == subject.version
      end

      it "should have the default iteration" do
        insist { @rpmtags[:release].to_s } == "1"
      end

      #it "should have the correct epoch" do
        #insist { @rpmtags[:epoch].first.to_s } == ""
      #end

      it "should have the default summary as first line of description" do
        insist { @rpmtags[:summary] } == @rpmtags[:description].split("\n").first
      end

      it "should output a package with the no conflicts" do
        # @rpm.requires is an array of [name, op, requires] elements
        # fpm uses strings here, so convert.
        conflicts = @rpm.conflicts.collect { |a| a.join(" ") }

        subject.conflicts.each do |dep|
          insist { conflicts }.include?(dep)
        end
      end

      it "should output a package with no provides" do
        # @rpm.requires is an array of [name, op, requires] elements
        # fpm uses strings here, so convert.
        provides = @rpm.provides.collect { |a| a.join(" ") }

        subject.provides.each do |dep|
          insist { provides }.include?(dep)
        end
      end
    end # package attributes

    context "dist" do
      it "should have the dist in the release" do
        subject.name = "example"
        subject.attributes[:rpm_dist] = "el6"
        subject.version = "1.0"
        @target = Stud::Temporary.pathname

        # Write RPM
        subject.output(@target)

        @rpm = ::RPM::File.new(@target)
        insist { @rpm.tags[:release] } == "#{subject.iteration}.el6"

        File.unlink(@target)
      end

      it "should accept the dist in the iteration" do
        subject.name = "example"
        subject.iteration = "1.el6"
        subject.version = "1.0"
        @target = Stud::Temporary.pathname

        # Write RPM
        subject.output(@target)

        @rpm = ::RPM::File.new(@target)
        insist { @rpm.tags[:release] } == "#{subject.iteration}"

        File.unlink(@target)
      end
    end # dist
  end # #output

  describe "prefix attribute" do
    it "should default to slash" do
      insist { subject.prefix } == "/"
    end
    it "should leave a single slash as it is" do
      subject.attributes[:prefix] = "/"
      insist { subject.prefix } == "/"
    end
    it "should leave a path without trailing slash it is" do
      subject.attributes[:prefix] = "/foo/bar"
      insist { subject.prefix } == "/foo/bar"
    end
    it "should remove trailing slashes" do
      subject.attributes[:prefix] = "/foo/bar/"
      insist { subject.prefix } == "/foo/bar"
    end
  end

  describe "regressions should not occur" do
    before do
      skip("Missing rpmbuild program") unless program_exists?("rpmbuild")
    end

    before :each do
      @tempfile_handle =
      @target = Stud::Temporary.pathname
      subject.name = "name"
      subject.version = "1.23"
    end

    after :each do
      subject.cleanup
      File.delete(@target) rescue nil
    end # after

    it "should escape '%' characters in filenames" do
      Dir.mkdir(subject.staging_path("/example"))
      File.write(subject.staging_path("/example/%name%"), "Hello")
      subject.output(@target)

      rpm = ::RPM::File.new(@target)
      insist { rpm.files } == [ "/example/%name%" ]
    end

    it "should correctly include files with spaces and quotation marks" do
      names = [
        "/It's time to go.txt",
        "/It's \"time\" to go.txt"
      ]

      names.each do |n|
        File.write(subject.staging_path("#{n}"), "Hello")
      end
      subject.output(@target)

      rpm = ::RPM::File.new(@target)
      insist { rpm.files.sort } == names.sort
    end

    it "should escape '%' characters in filenames while preserving permissions" do
      Dir.mkdir(subject.staging_path("/example"))
      File.write(subject.staging_path("/example/%name%"), "Hello")
      File.chmod(01777,subject.staging_path("/example/%name%"))
      subject.attributes[:rpm_use_file_permissions?] = true
      subject.output(@target)

      rpm = ::RPM::File.new(@target)
      insist { rpm.files } == [ "/example/%name%" ]
      insist { `rpm -qlv -p #{@target}`.chomp.split.first } == "-rwxrwxrwt"
    end

    it "should permit spaces in filenames (issue #164)" do
      File.write(subject.staging_path("file with space"), "Hello")

      # This will raise an exception if rpmbuild fails.
      subject.output(@target)
      rpm = ::RPM::File.new(@target)
      insist { rpm.files } == [ "/file with space" ]
    end

    it "should permit brackets in filenames (issue #202)" do
      File.write(subject.staging_path("file[with]bracket"), "Hello")

      # This will raise an exception if rpmbuild fails.
      subject.output(@target)
      rpm = ::RPM::File.new(@target)
      insist { rpm.files } == [ "/file[with]bracket" ]
    end

    it "should permit asterisks in filenames (issue #202)" do
      File.write(subject.staging_path("file*asterisk"), "Hello")

      # This will raise an exception if rpmbuild fails.
      subject.output(@target)
      rpm = ::RPM::File.new(@target)
      insist { rpm.files } == [ "/file*asterisk" ]
    end

    it "should have some reasonable defaults that never change" do
      subject.output(@target)
      # Read the rpm
      rpm = ::RPM::File.new(@target)

      rpmtags = {}
      rpm.header.tags.each do |tag|
        rpmtags[tag.tag] = tag.value
      end

      # Default epoch must be empty, see #381
      # For some reason, epoch is an array of numbers in rpm?
      insist { rpmtags[:epoch] } == nil

      # Default release must be '1'
      insist { rpmtags[:release] } == "1"
    end

    context "with an empty description" do
      it "should build a package" do
        subject.description = ""
        expect do
          subject.output(@target)
        end.not_to raise_error
      end
    end

    context "with an one-line description" do
      it "should build a package" do
        subject.description = "hello world"
        expect do
          subject.output(@target)
        end.not_to raise_error
      end
    end
  end # regression stuff

  describe "input validation stuff" do
    before do
      skip("Missing rpmbuild program") unless program_exists?("rpmbuild")
    end

    before :each do
      @tempfile_handle =
      @target = Stud::Temporary.pathname
      @generator = FPM::Package::RPM.new

      @generator.name = "name"
      @generator.version = "1.23"
    end

    after :each do
      subject.cleanup
      @generator.cleanup
      #File.delete(@target) rescue nil
    end # after

    it "should not cause errors when reading basic rpm in input (#802)" do
      # Write the rpm out
      @generator.output(@target)

      # Load generated rpm
      subject.input(@target)

      # Value sanity check
      insist { subject.name } == "name"
      insist { subject.version } == "1.23"
    end

    it "should not cause errors when reading more complete rpm in input (#802)" do
      @generator.architecture = "all"
      @generator.iteration = "100"
      @generator.epoch = "5"
      @generator.dependencies << "something > 10"
      @generator.dependencies << "hello >= 20"
      @generator.conflicts << "bad < 2"
      @generator.license = "this\nis\nan\example"
      @generator.provides << "bacon = 1.0"

      # Write the rpm out
      @generator.output(@target)

      # Load generated rpm
      subject.input(@target)

      # Value sanity check
      insist { subject.name } == "name"
      insist { subject.version } == "1.23"
      insist { subject.architecture } == "noarch" # see #architecture
      insist { subject.iteration } == "100"
      insist { subject.epoch } == 5
      insist { subject.dependencies }.include?("something > 10")
      insist { subject.dependencies }.include?("hello >= 20")
      insist { subject.conflicts[0] } == "bad < 2"
      insist { subject.license } == @generator.license.split("\n").join(" ") # See issue #252
      insist { subject.provides[0] } == "bacon = 1.0"

    end
    it "should not cause errors when reading rpm with script in input (#802)" do
      @generator.scripts[:before_install] = "example before_install"
      @generator.scripts[:after_install] = "example after_install"
      @generator.scripts[:before_remove] = "example before_remove"
      @generator.scripts[:after_remove] = "example after_remove"
      @generator.scripts[:rpm_verifyscript] = "example rpm_verifyscript"
      @generator.scripts[:rpm_posttrans] = "example rpm_posttrans"
      @generator.scripts[:rpm_pretrans] = "example rpm_pretrans"

      # Write the rpm out
      @generator.output(@target)

      # Load generated rpm
      subject.input(@target)

      # Value sanity check
      insist { subject.name } == "name"
      insist { subject.version } == "1.23"
      insist { subject.scripts[:before_install] } == "example before_install"
      insist { subject.scripts[:after_install] } == "example after_install"
      insist { subject.scripts[:before_remove] } == "example before_remove"
      insist { subject.scripts[:after_remove] } == "example after_remove"
      insist { subject.scripts[:rpm_verifyscript] } == "example rpm_verifyscript"
      insist { subject.scripts[:rpm_posttrans] } == "example rpm_posttrans"
      insist { subject.scripts[:rpm_pretrans] } == "example rpm_pretrans"
    end

    it "should not cause errors when reading rpm with triggers in input (#802)" do
      @generator.attributes[:rpm_trigger_before_install] = [["test","#!/bin/sh\necho before_install trigger executed\n"]]
      @generator.attributes[:rpm_trigger_after_install] = [["test","#!/bin/sh\necho after_install trigger executed\n"]]
      @generator.attributes[:rpm_trigger_before_uninstall] = [["test","#!/bin/sh\necho before_uninstall trigger executed\n"]]
      @generator.attributes[:rpm_trigger_after_target_uninstall] = [["test","#!/bin/sh\necho after_target_uninstall trigger executed\n"]]

      # Write the rpm out
      @generator.output(@target)

      # Load generated rpm
      subject.input(@target)

      # Value sanity check
      insist { subject.name } == "name"
      insist { subject.version } == "1.23"
      insist { subject.attributes[:rpm_trigger_before_install] } == [["test","#!/bin/sh\necho before_install trigger executed", ""]]
      insist { subject.attributes[:rpm_trigger_after_install] } == [["test","#!/bin/sh\necho after_install trigger executed", ""]]
      insist { subject.attributes[:rpm_trigger_before_uninstall] } == [["test","#!/bin/sh\necho before_uninstall trigger executed", ""]]
      insist { subject.attributes[:rpm_trigger_after_target_uninstall] } == [["test","#!/bin/sh\necho after_target_uninstall trigger executed", ""]]
    end
  end # input validation stuff

  describe "rpm_use_file_permissions" do
    let(:target) { Stud::Temporary.pathname }
    let(:rpm) { ::RPM::File.new(target) }
    let(:path) { "hello.txt" }
    let(:path_stat) { File.lstat(subject.staging_path(path)) }

    before :each do
      File.write(subject.staging_path(path), "Hello world")
      subject.name = "example"
      subject.version = "1.0"
    end

    after :each do
      subject.cleanup
      File.delete(target) rescue nil
    end

    it "should respect file user and group ownership" do
      skip("Missing rpmbuild program") unless program_exists?("rpmbuild")
      subject.attributes[:rpm_use_file_permissions?] = true
      subject.output(target)
      insist { rpm.tags[:fileusername].first } == Etc.getpwuid(path_stat.uid).name
      insist { rpm.tags[:filegroupname].first } == Etc.getgrgid(path_stat.gid).name
    end

    it "rpm_group should override rpm_use_file_permissions-derived owner" do
      skip("Missing rpmbuild program") unless program_exists?("rpmbuild")
      subject.attributes[:rpm_use_file_permissions?] = true
      subject.attributes[:rpm_user] = "hello"
      subject.attributes[:rpm_group] = "world"
      subject.output(target)
      insist { rpm.tags[:fileusername].first } == subject.attributes[:rpm_user]
      insist { rpm.tags[:filegroupname].first } == subject.attributes[:rpm_group]
    end
  end

  describe "#output with digest and compression settings" do
    before do
      skip("Missing rpmbuild program") unless program_exists?("rpmbuild")
    end

    context "bzip2/sha1" do
      before :each do
        @target = Stud::Temporary.pathname
        subject.name = "name"
        subject.version = "123"
        subject.architecture = "all"
        subject.iteration = "100"
        subject.epoch = "5"
        subject.attributes[:rpm_compression] = "bzip2"
        subject.attributes[:rpm_digest] = "sha1"

        # Write the rpm out
        subject.output(@target)

        # Read the rpm
        @rpm = ::RPM::File.new(@target)

        @rpmtags = {}
        @rpm.header.tags.each do |tag|
          @rpmtags[tag.tag] = tag.value
        end
      end

      after :each do
        subject.cleanup
        File.delete(@target)
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
