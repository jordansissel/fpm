require "spec_setup"
require "fpm" # local
require "fpm/package/dir" # local

describe FPM::Package::Dir do
  before :each do
    @source = FPM::Package::Dir.new
    @rush = Rush::Box.new("localhost")
    @tmpdir = @rush[::Dir.mktmpdir("package-test-tmpdir")]
    @output = @rush[::Dir.mktmpdir("package-test-output")]
  end # before

  after :each do
    @source.cleanup
    FileUtils.rm_r(@tmpdir.full_path)
    FileUtils.rm_r(@output.full_path)
  end # after

  it "single file: should copy single files to the root of the output" do
    file = @tmpdir["hello"]
    file.write "Hello world"
    @source.input(@tmpdir.full_path)
    @source.output(@output.full_path)

    path = File.join(".", file.full_path)
    insist { @output[path].contents } == file.contents
    #assert_equal(@output[File.join(".", file.full_path)].contents,
                 #file.contents, "The file #{@tmpdir["hello"].full_path} should appear in the output")
  end

  it "should copy the full path given (single file)" do
    dir = @tmpdir.create_dir("a/b/c")
    file = dir.create_file("hello")
    file.write "Hello world"
    @source.input(@tmpdir.full_path)
    @source.output(@output.full_path)

    path = File.join(".", file.full_path)
    insist { @output[path].contents } == file.contents
    #assert_equal(@output[File.join(".", file.full_path)].contents,
                 #file.contents, "The file #{@tmpdir["a/b/c/hello"].full_path} should appear in the output")
  end

  it "should copy entire directories given as input" do
    dir = @tmpdir.create_dir("a/b/c")
    files = rand(50).times.collect do |i|
      dir.create_file("hello-#{i}")
    end
    files.each { |f| f.write(rand(1000)) }

    @source.input(@tmpdir.full_path)
    @source.output(@output.full_path)

    files.each do |file|
      path = File.join(".", file.full_path)
      insist { @output[path].contents } == file.contents
                   #file.contents, "The file #{file.full_path} should appear in the output")
    end
  end

  it "should obey the :prefix attribute" do
    prefix = @source.attributes[:prefix] = "/usr/local"
    file = @tmpdir["hello"]
    file.write "Hello world"
    @source.input(@tmpdir.full_path)
    @source.output(@output.full_path)

    expected_path = File.join(".", file.full_path)
    path = File.join(prefix, expected_path)
    insist { @output[path].contents } == file.contents
                 #file.contents, "The file #{@tmpdir["hello"].full_path} should appear in the output")
  end

  it "should obey :chdir and :prefix attributes together" do
    prefix = @source.attributes[:prefix] = "/usr/local"
    chdir = @source.attributes[:chdir] = @tmpdir.full_path
    file = @tmpdir["hello"]
    file.write "Hello world"
    @source.input(".") # since we chdir, copy the entire root
    @source.output(@output.full_path)

    # path relative to the @output directory.
    expected_path = File.join(".", prefix, file.name)
    insist { @output[expected_path].contents } == file.contents
                 #file.contents, "The file #{@tmpdir["hello"].full_path} should appear in the output")
  end
end # describe FPM::Package::Dir
