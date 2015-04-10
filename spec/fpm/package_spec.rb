require "spec_setup"
require "fpm" # local

describe FPM::Package do
  after do
    subject.cleanup
  end # after

  shared_examples_for :Default do |item, default|
    context "default value" do
      it "should be #{default}" do
        if default.nil?
          expect(subject.send(item)).to(be_nil)
        else
          expect(subject.send(item)).to(be == default)
        end
      end
    end
  end

  shared_examples_for :Mutator do |item|
    context "when set" do
      let(:value) { "whatever" }
      it "should return the set value" do
        expect(subject.send("#{item}=", value)).to(be == value)
      end

      context "the getter" do
        before do
          subject.send("#{item}=", value)
        end
        it "returns the value set previously" do
          expect(subject.send(item)).to(be == value)
        end
      end
    end
  end

  describe "#name" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, nil
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#version" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, nil
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#architecture" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, "native"
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#attributes" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, {}
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#category" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, "default"
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#config_files" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, []
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#conflicts" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, []
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#dependencies" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, []
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#description" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, "no description given"
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#epoch" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, nil
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#iteration" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, nil
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#license" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, "unknown"
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#maintainer" do
    require "socket"
    default_maintainer = "<#{ENV["USER"]}@#{Socket.gethostname}>"
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, default_maintainer
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#provides" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, []
  end

  describe "#replaces" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, []
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#scripts" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, {}
  end

  describe "#url" do 
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, nil
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
  end

  describe "#vendor" do
    it_behaves_like :Default, description.gsub(/^#/, "").to_sym, "none"
    it_behaves_like :Mutator, description.gsub(/^#/, "").to_sym
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
      subject.attributes[:excludes] = ["example"]
      subject.instance_eval { exclude }
      insist { subject.files } == ["keeper"]
    end

    it "should obey attributes[:excludes] for child directories" do
      Dir.mkdir(subject.staging_path("example"))
      Dir.mkdir(subject.staging_path("example/foo"))
      File.write(subject.staging_path("example/foo/delete_me"), "Hello!")
      File.write(subject.staging_path("keeper"), "Hello!")
      subject.attributes[:excludes] = ["example/foo"]
      subject.instance_eval { exclude }
      insist { subject.files.sort } == ["example", "keeper"]
    end
  end

  describe "#script (internal method)" do
    scripts = [:after_install, :before_install, :after_remove, :before_remove]
    before do
      scripts.each do |script|
        subject.scripts[script] = "<%= name %>"
      end
      subject.name = "Example"
    end

    context "when :template_scripts? is true" do
      before do
        subject.attributes[:template_scripts?] = true
      end

      scripts.each do |script|
        it "should evaluate #{script} as a template" do
          expect(subject.script(script)).to(be == subject.name)
        end
      end
    end

    context "when :template_scripts? is false" do
      before do
        subject.attributes[:template_scripts?] = false
      end

      scripts.each do |script|
        it "should not process #{script} as a template" do
          expect(subject.script(script)).to(be == subject.scripts[script])
        end
      end
    end

    it "should not template by default" do
      expect(subject.attributes[:template_scripts?]).to(be_falsey)
    end
  end
end # describe FPM::Package
