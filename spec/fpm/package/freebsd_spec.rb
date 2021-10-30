require "spec_setup"
require "fpm" # local
require "fpm/package/freebsd" # local
require "stud/temporary"

describe FPM::Package::FreeBSD do
  context "#output" do
    subject { FPM::Package::FreeBSD.new }
    let(:package) { Stud::Temporary.pathname }
    let(:allfiles) { `tar -Jtf #{package} 2> /dev/null`.split("\n") }
    let(:files) { allfiles - [ "+COMPACT_MANIFEST", "+MANIFEST" ] }

    before do
      Dir.mkdir(subject.staging_path("/usr"))
      Dir.mkdir(subject.staging_path("/usr/bin"))
      File.write(subject.staging_path("/usr/bin/example"), "testing")
      File.write(subject.staging_path("/usr/bin/hello"), "world")
      subject.output(package)
    end

    after do
      subject.cleanup
      File.unlink(package)
    end

    context "tarball" do
      it "should have a +COMPACT_MANIFEST file" do
        insist { allfiles }.include?("+COMPACT_MANIFEST")
      end

      it "should have a +MANIFEST file" do
        insist { allfiles }.include?("+MANIFEST")
      end

      # Ensure files have a leading / - Issue #1811, #1844
      it "should have files with a leading slash" do
        files.each do |path|
          insist { path }.start_with?("/")
        end
      end

      it "should contain expected files" do
        insist { files }.include?("/usr/bin/example")
        insist { files }.include?("/usr/bin/hello")
      end
    end

    context "+MANIFEST" do
      let(:manifest) { JSON.parse(`tar -Jxf #{package} -O +MANIFEST`) }
      it "should have a files list identical to the tar contents" do
        insist { files.sort } == manifest["files"].keys.sort
      end

      [ "arch", "name", "version", "comment", "desc", "origin",
        "maintainer", "www", "prefix", "files", "scripts" ].each do |field|
        it "should have a top-level '#{field}'" do
          insist { manifest.keys }.include?(field)
        end
      end
    end
  end
end
