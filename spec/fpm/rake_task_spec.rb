require "rspec" # Avoid setup_spec due to overrides
require "fpm/command"
require "fpm/rake_task"
require "tmpdir"

describe FPM::RakeTask do
  around do |example|
    old_stderr = $stderr.dup
    $stderr.reopen("/dev/null")

    example.run

    $stderr = old_stderr
    Rake::Task.clear
  end

  describe "#new" do
    it "requires a package name" do
      expect { described_class.new(nil, :source => :dir, :target => :tar) }.
        to raise_error(SystemExit, "Must specify package name, source and output")
    end

    it "requires a source" do
      expect { described_class.new(:awesome, :source => nil, :target => :tar) }.
        to raise_error(SystemExit, "Must specify package name, source and output")
    end

    it "requires a target" do
      expect { described_class.new(:awesome, :source => :dir, :target => nil) }.
        to raise_error(SystemExit, "Must specify package name, source and output")
    end

    it "requires package args" do
      described_class.new(:awesome, :source => :dir, :target => :tar)
      expect { Rake::Task["awesome"].execute }.
        to raise_error(SystemExit, "Must specify args")
    end

    it "executes FPM::Command with the appropriate arguments" do
      command = instance_double(FPM::Command)
      expected = %W(-t tar -s dir -C #{Dir.tmpdir} --cpan-mirror-only
                    --no-cpan-test --config-files foo --config-files bar
                    --name awesome --cpan-mirror-only --url http://example.com
                    bin/)

      allow(FPM::Command).to receive(:new).and_return(command)
      expect(command).to receive(:run).with(array_including(*expected))

      args = [:awesome,
              { :source => :dir, :target => :tar, :directory => Dir.tmpdir }]

      described_class.new(*args) do |pkg|
        pkg.args = %w(bin/)
        pkg.cpan_mirror_only = true
        pkg.cpan_test = false
        pkg.url = "http://example.com"
        pkg.config_files = %w(foo bar)
      end

      expect { Rake::Task["awesome"].execute }.to raise_error(SystemExit, nil)
    end
  end
end
