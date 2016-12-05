require "spec_setup"
require "fpm" # local
require "fpm/package/dir" # local
require "stud/temporary"

if RUBY_VERSION =~ /^1\.8/
  # The following method copied from ruby 1.9.3
  module SecureRandom
    def self.uuid
      ary = self.random_bytes(16).unpack("NnnnnN")
      ary[2] = (ary[2] & 0x0fff) | 0x4000
      ary[3] = (ary[3] & 0x3fff) | 0x8000
      "%08x-%04x-%04x-%04x-%04x%08x" % ary
    end
  end
end

describe FPM::Package::Dir do
  let(:tmpdir) { Stud::Temporary.directory("tmpdir") }
  let(:output) { Stud::Temporary.directory("output") }
  #let(:tmpdir) { ::Dir.mkdir("/tmp/tmpdir"); "/tmp/tmpdir" }
  #let(:output) { ::Dir.mkdir("/tmp/output"); "/tmp/output" }

  after :each do
    subject.cleanup
    FileUtils.rm_r(tmpdir)
    FileUtils.rm_r(output)
  end # after

  it "single file: should copy single files to the root of the output" do
    hello_in = File.join(tmpdir, "hello")
    hello_out = File.join(output, tmpdir, "hello")
    file = File.write(hello_in, "Hello world")
    subject.input(tmpdir)
    subject.output(output)
    insist { File.read(hello_out) } == File.read(hello_in)
  end

  it "should copy the full path given (single file)" do
    dir = File.join(tmpdir, "a", "b", "c")
    FileUtils.mkdir_p(dir)
    hello_in = File.join(dir, "hello")
    hello_out = File.join(output, dir, "hello")
    File.write(hello_in, "Hello world")
    subject.input(tmpdir)
    subject.output(output)
    insist { File.read(hello_out) } == File.read(hello_in)
  end

  it "should copy entire directories given as input" do
    dir = File.join(tmpdir, "a", "b", "c")
    FileUtils.mkdir_p(dir)
    files = rand(50).times.collect do |i|
      file = File.join(dir, "hello-#{i}")
      File.write(file, rand(1000))
      next file
    end

    subject.input(tmpdir)
    subject.output(output)

    files.each do |file|
      insist { File.read(File.join(output, file)) } == File.read(file)
    end
  end

  it "should obey the :prefix attribute" do
    prefix = subject.attributes[:prefix] = "/usr/local"
    file = File.join(tmpdir, "hello")
    File.write(file, "Hello world")
    subject.input(tmpdir)
    subject.output(output)

    expected_path = File.join(".", file)
    path = File.join(prefix, expected_path)
    insist { File.read(File.join(output, path)) } == File.read(file)
  end

  it "should obey :chdir and :prefix attributes together" do
    prefix = subject.attributes[:prefix] = "/usr/local"
    chdir = subject.attributes[:chdir] = tmpdir
    file = File.join(tmpdir, "hello")
    File.write(file, "Hello world")
    subject.input(".") # since we chdir, copy the entire root
    subject.output(output)

    # path relative to the @output directory.
    expected_path = File.join(".", prefix, File.basename(file))
    insist { File.read(File.join(output, expected_path)) } == File.read(file)
  end

  context "path mapping" do
    # 'rsync -a' semantics
    mappings = {
      # this input    => should produce this file
      "/a/b=/example" => "./example",
      "/a/b=/example/" => "./example/b",
      "/a=/example/" => "./example/a/b",
      "/a=/example" => "./example/a/b",
      "/a/=/example/" => "./example/b"
    }

    mappings.each do |input, expected_file|
      it "should take #{input} and produce #{expected_file}" do
        Dir.mkdir(File.join(tmpdir, "a"))
        File.write(File.join(tmpdir, "a", "b"), "hello world")
        subject.input(File.join(tmpdir, input))
        subject.output(output)
        insist { File }.exist?(File.join(output, expected_file))
      end
    end

    it "should not map existing paths with = in them" do
      File.write(File.join(tmpdir, "a=b"), "hello world")
      subject.input(File.join(tmpdir, "a=b"))
      subject.output(output)
      insist { File }.exist?(File.join(output, tmpdir, "a=b"))
    end

    it "should not map existing paths with = in them and obey :chdir and :prefix attributes" do
      Dir.mkdir(File.join(tmpdir, "a"))
      File.write(File.join(tmpdir,"a",  "a=b"), "hello world")
      subject.attributes[:chdir] = tmpdir
      subject.attributes[:prefix] = "/foo"
      subject.input(File.join("a", "a=b"))
      subject.output(output)
      insist { File }.exist?(File.join(output, "foo", "a", "a=b"))
    end
  end

  context "SYMLINKS." do
    let(:path) { Stud::Temporary.pathname }
    let(:broken_target) { File.join("no", "such", "path", "here", rand(1000).to_s, rand(1000).to_s) }
    before do
      File.symlink(broken_target, path)
    end
    after do
      File.unlink(path)
    end
    it "should copy a broken symlink because it shouldn't be following symlinks to begin with" do
      subject.input(path)
    end
  end

  context "symlink=dest_symlink." do
    it "Should not put the symlink into directory" do
      filepath = File.join(tmpdir, "target")
      File.write(filepath, "hello!");
      symlinkpath = File.join(tmpdir, "properlink.so")
      File.symlink(filepath, symlinkpath);

      subject.input(symlinkpath + "=" + "/a/b/properlink.so")
      subject.output(output)
      insist { File.read(File.join(output, "/a/b/properlink.so")) } == "hello!"
    end
  end

  context "symlink=dest_dir/" do
    it "Should put the symlink into directory with link syntax" do
      filepath = File.join(tmpdir, "target")
      File.write(filepath, "hello!");
      symlinkpath = File.join(tmpdir, "link.so")
      File.symlink(filepath, symlinkpath);

      subject.input(symlinkpath)
      subject.output(output)
      insist { File.read(File.join(output, symlinkpath)) } == "hello!"
    end
  end
end # describe FPM::Package::Dir
