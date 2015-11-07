require "spec_setup"
require 'fileutils'
require "fpm" # local
require "fpm/package/pacman" # local
require "stud/temporary"

describe FPM::Package::Pacman do
  let(:target) { Stud::Temporary.pathname + ".pkg.tar.xz" }
  after do
    subject.cleanup
    File.unlink(target) if File.exist?(target)
  end

  describe "#architecture" do
    it "should convert amd64 to x86_64" do
      subject.architecture = "amd64"
      expect(subject.architecture).to(be == "x86_64")
    end

    it "should convert noarch to any" do
      subject.architecture = "noarch"
      expect(subject.architecture).to(be == "any")
    end

    let(:native) { `uname -m`.chomp }

    it "should default to native" do
      # Convert kernel name to debian name
      expect(subject.architecture).to(be == native)
    end
  end

  describe "#iteration" do
    it "should default to 1" do
      expect(subject.iteration).to(be == 1)
    end
  end

  describe "#epoch" do
    it "should default to nil" do
      expect(subject.epoch).to(be_nil)
    end
  end

  describe "#optional_depends" do
    it "should default to []" do
      expect(subject.attributes[:pacman_optional_depends]).to(be == [])
    end
  end

  describe "#to_s" do
    before do
      subject.name = "name"
      subject.version = "123"
      subject.architecture = "any"
      subject.iteration = "100"
      subject.epoch = "5"
    end

    it "should have a default output usable as a filename" do
      # This is the default filename I see commonly produced by debuild
      insist { subject.to_s } == "name-123-100-any.pkg.tar.xz"
    end

    context "when iteration is nil" do
      before do
        subject.iteration = nil
      end

      it "should have an iteration of `1`" do
        # This is the default filename I see commonly produced by debuild
        expect(subject.to_s).to(be == "name-123-1-any.pkg.tar.xz")
      end
    end
  end

  describe "#output" do
    let(:original) { FPM::Package::Pacman.new }
    let(:input) { FPM::Package::Pacman.new }

    context "Test that empty epoch is tested properly" do
      before do

        original.name = "foo"
        original.version = "123"
        original.iteration = "100"
        # original.epoch conspicuously absent
        original.architecture = "all"
        original.output(target)
        input.input(target)
      end
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
    end


    context "normal tests" do
      before do
        # output a package, use it as the input, set the subject to that input
        # package. This helps ensure that we can write and read packages
        # properly.
        # The target file must not exist.

        original.name = "foo"
        original.version = "123"
        original.iteration = "100"
        original.epoch = "5"
        original.architecture = "all"
        original.dependencies << "hello >= 20"
        original.dependencies << "something > 10"
        original.dependencies << "rpmlib(bogus)"
        original.dependencies << "/usr/bin/bad-dep"
        original.provides << "#{original.name} = #{original.version}"

        original.conflicts = ["foo < 123"]
        original.attributes[:pacman_opt_depends] = ["bamb > 10"]
        original.directories << '/var/lib/foo'

        ::Dir.chdir(original.staging_path) do
          FileUtils::mkdir_p 'usr/bin'
          File.open('usr/bin/foo', 'w') do |exe|
            exe.write("Frankly, I think the odds are slightly in your favor " \
                      "at hand fighting.")
          end
          File.chmod(0755, 'usr')
          File.chmod(0755, 'usr/bin')
          File.chmod(0755, 'usr/bin/foo')
          FileUtils::mkdir_p 'usr/share/doc'
          File.chmod(0755, 'usr/share')
          File.chmod(0755, 'usr/share/doc')
          File.open('usr/share/doc/foo.txt', 'w') do |doc|
            doc.write("It's not my fault I'm the biggest or the strongest.")
          end
          File.chmod(0644, 'usr/share/doc/foo.txt')
          FileUtils::mkdir_p 'usr/lib'
          # incorrectly permissioned path (but that's what these tests are for)
          File.chmod(0700, 'usr/lib')
          File.open('usr/lib/libfoo.so', 'w') do |lib|
            lib.write("I don't even excercise.")
          end
          File.chmod(0755, 'usr/lib/libfoo.so')
          FileUtils::mkdir_p 'etc'
          File.chmod(0755, 'etc')
          File.open('etc/foo.conf', 'w') do |conf|
            conf.write("You mean, you'll put down your rock and I'll put down " \
                       "my sword, and we'll try and kill each other like " \
                       "civilized people?")
          end
          File.chmod(0600, 'etc/foo.conf')
          FileUtils::mkdir_p 'var/lib/foo'
          File.chmod(0755, 'var')
          File.chmod(0755, 'var/lib')
          File.chmod(0755, 'var/lib/foo')
        end

        [:before_install, :after_install, :before_remove, :after_remove,
         :before_upgrade, :after_upgrade].each do |script|
          original.scripts[script] = "#!/bin/sh\n\necho #{script.to_s}"
        end

        original.output(target)
        input.input(target)
      end

      after do
        original.cleanup
        input.cleanup
      end # after

      context "script contents" do
        [:before_install, :after_install, :before_remove, :after_remove,
         :before_upgrade, :after_upgrade].each do |script|
          it "should be the same both with input as with original for #{script.to_s}" do
            expect( \
                   (input.scripts[script] =~ \
                    /[\n :]+#{Regexp.quote(original.scripts[script])}/m \
                   )
                  ).to(be_truthy)
          end
        end
      end

      context "file permissions" do
        {"/usr" => 0755,
         "/usr/bin" => 0755,
         "/usr/bin/foo" => 0755,
         "/usr/lib" => 0700,
         "/usr/lib/libfoo.so" => 0755,
         "/usr/share" => 0755,
         "/usr/share/doc" => 0755,
         "/usr/share/doc/foo.txt" => 0644,
         "/etc" => 0755,
         "/etc/foo.conf" => 0600,
         "/var" => 0755,
         "/var/lib" => 0755,
         "/var/lib/foo" => 0755}.each do |dir, perm|
           it "should preserve file permissions for #{dir}" do
             insist { File.stat(File.join(input.staging_path,
                                          dir)).mode & 07777 } == perm
           end
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

        it "should not have bogus dependencies, just correct dependencies" do
          expect(input.dependencies).to(be == ["hello >= 20", "something > 10"])
        end
      end # package attributes
    end # #output
  end
  # TODO: output sometimes make fu-:1.2.3.out.rpm or something. Make sure the
  # version isn't screwed up in transit.
end # describe FPM::Package::Pacman
