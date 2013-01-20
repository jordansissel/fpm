require "spec_setup"
require "fpm" # local

describe FPM::Package do
  before :each do
    subject { FPM::Package.new }
  end # before

  after :each do
    subject.cleanup
  end # after

  describe "#name" do
    it "should have no default name" do
      insist { subject.name }.nil?
    end

    it "should allow setting the package name" do
      name = "my-package"
      subject.name = name
      insist { subject.name } == name
    end
  end

  describe "#version" do
    it "should default to nil" do
      insist { subject.version }.nil?
    end

    it "should allow setting the package name" do
      version = "hello"
      subject.version = version
      insist { subject.version } == version
    end
  end

  describe "#architecture" do
    it "should default to native" do
      insist { subject.architecture } == "native"
    end
  end

  describe "#attributes" do
    it "should be empty by default" do
      insist { subject.attributes }.empty?
    end
  end

  describe "#category" do
    it "should be 'default' by default" do
      insist { subject.category } == "default"
    end
  end

  describe "#config_files" do
    it "should be empty by default" do
      insist { subject.config_files }.empty?
    end
  end

  describe "#conflicts" do
    it "should be empty by default" do
      insist { subject.conflicts }.empty?
    end
  end

  describe "#dependencies" do
    it "should be empty by default" do
      insist { subject.dependencies }.empty?
    end
  end

  describe "#description" do
    it "should be 'no description given' by default" do
      insist { subject.description } == "no description given"
    end
  end

  describe "#epoch" do
    it "should be nil by default" do
      insist { subject.epoch }.nil?
    end
  end

  describe "#iteration" do
    it "should be nil by default" do
      insist { subject.iteration }.nil?
    end
  end

  describe "#license" do
    it "should be 'unknown' by default" do
      insist { subject.license } == "unknown"
    end
  end

  describe "#maintainer" do
    it "should use user@host by default" do
      require "socket"
      insist { subject.maintainer } == "<#{ENV["USER"]}@#{Socket.gethostname}>"
    end
  end

  describe "#provides" do
    it "should be empty by default" do
      insist { subject.provides }.empty?
    end
  end

  describe "#replaces" do
    it "should be empty by default" do
      insist { subject.provides }.empty?
    end
  end

  describe "#scripts" do
    # This api for 'scripts' kind of sucks.
    it "should default to an empty hash" do
      insist { subject.scripts } == {}
    end
  end

  describe "#url" do 
    it "should be nil by default" do
      insist { subject.url }.nil?
    end
  end

  describe "#vendor" do
    it "should be 'none' by default" do
      insist { subject.vendor } == "none"
    end
  end

  describe "#exclude (internal method)" do
    it "should obey attributes[:excludes]" do
      File.write(subject.staging_path("hello"), "hello")
      File.write(subject.staging_path("world"), "world")
      subject.attributes[:excludes] = ["*world*"]
      subject.instance_eval { exclude }
      insist { subject.files } == ["hello"]
    end

    it "should obey attributes[:excludes] for directories" do
      Dir.mkdir(subject.staging_path("example"))
      Dir.mkdir(subject.staging_path("example/foo"))
      File.write(subject.staging_path("example/foo/delete_me"), "Hello!")
      File.write(subject.staging_path("keeper"), "Hello!")
      subject.attributes[:excludes] = [ "example" ]
      subject.instance_eval { exclude }
      insist { subject.files } == [ "keeper" ]
    end

    it "should obey attributes[:excludes] for child directories" do
      Dir.mkdir(subject.staging_path("example"))
      Dir.mkdir(subject.staging_path("example/foo"))
      File.write(subject.staging_path("example/foo/delete_me"), "Hello!")
      File.write(subject.staging_path("keeper"), "Hello!")
      subject.attributes[:excludes] = [ "example/foo" ]
      subject.instance_eval { exclude }
      insist { subject.files.sort } == [ "example", "keeper" ]
    end
  end

  context "#script (internal method)" do
    it "should template when :template_scripts? is true" do
      subject.scripts[:after_install] = "<%= name %>"
      subject.scripts[:before_install] = "<%= name %>"
      subject.scripts[:after_remove] = "<%= name %>"
      subject.scripts[:before_remove] = "<%= name %>"
      subject.attributes[:template_scripts?] = true
      subject.name = "Example"
      insist { subject.script(:after_install) } == subject.name
      insist { subject.script(:before_install) } == subject.name
      insist { subject.script(:after_remove) } == subject.name
      insist { subject.script(:before_remove) } == subject.name
    end

    it "should not template when :template_scripts? is false" do
      subject.scripts[:after_install] = "<%= name %>"
      subject.scripts[:before_install] = "<%= name %>"
      subject.scripts[:after_remove] = "<%= name %>"
      subject.scripts[:after_install] = "<%= name %>"
      subject.attributes[:template_scripts?] = false
      insist { subject.script(:after_install) } == subject.scripts[:after_install]
      insist { subject.script(:before_install) } == subject.scripts[:before_install]
      insist { subject.script(:after_remove) } == subject.scripts[:after_remove]
      insist { subject.script(:before_remove) } == subject.scripts[:before_remove]
    end

    it "should not template by default" do
      subject.scripts[:after_install] = "<%= name %>"
      insist { subject.script(:after_install) } == subject.scripts[:after_install]
    end
  end
end # describe FPM::Package
