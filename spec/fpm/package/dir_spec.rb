require "spec_setup"
require "fpm" # local
require "fpm/package/dir" # local
require "stud/temporary"

describe FPM::Package::Dir do
  #let(:tmpdir) { Stud::Temporary.directory("tmpdir") }
  #let(:output) { Stud::Temporary.directory("output") }
  let(:tmpdir) { ::Dir.mkdir("/tmp/tmpdir"); "/tmp/tmpdir" }
  let(:output) { ::Dir.mkdir("/tmp/output"); "/tmp/output" }

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
    it "should map a file -> directory" do
      file = File.join(tmpdir, "hello")
      File.write(file, "Hello world")
      subject.input("#{tmpdir}=/usr/local")
      subject.output(output)
      insist { File }.exists?(File.join(output, "/usr/local", "hello"))
    end

    it "should map a directory -> directory" do
      file = File.join(tmpdir, "example", "hello")
      dir = File.dirname(file)
      ::Dir.mkdir(dir)
      File.write(file, "Hello world")
      subject.input("#{tmpdir}=/usr/local")
      subject.output(output)
      insist { File }.exists?(File.join(output, "/usr/local", "example", "hello"))
    end
  end
end # describe FPM::Package::Dir
