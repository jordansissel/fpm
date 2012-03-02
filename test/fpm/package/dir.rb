require "rubygems"
require File.join(File.dirname(File.expand_path(__FILE__)), "..", "..", "testing")
$: << File.join(File.dirname(File.expand_path(__FILE__)), "..", "..", "..", "lib")
require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "fpm/package/dir"
require "rush" # for simple file stuff

describe FPM::Package::Dir do
  before do
    @source = FPM::Package::Dir.new
    @rush = Rush::Box.new("localhost")
    @tmpdir = @rush[::Dir.mktmpdir("package-test-tmpdir")]
    @output = @rush[::Dir.mktmpdir("package-test-output")]
  end # before

  after do
    @source.cleanup
    FileUtils.rm_r(@tmpdir.full_path)
    FileUtils.rm_r(@output.full_path)
  end # after

  test "adding a single file" do
    file = @tmpdir["hello"]
    file.write "Hello world"
    @source.input(@tmpdir.full_path)
    @source.output(@output.full_path)

    #p :input => @tmpdir.full_path
    #p :output => @output.full_path
    #p :file => file.full_path
    #sleep 500
    assert_equal(@output[File.join(".", file.full_path)].contents,
                 file.contents, "The file #{@tmpdir["hello"].full_path} should appear in the output")
  end

  test "single file in a directory" do
    dir = @tmpdir.create_dir("a/b/c")
    file = dir.create_file("hello")
    file.write "Hello world"
    @source.input(@tmpdir.full_path)

    @source.output(@output.full_path)
    assert_equal(@output[File.join(".", file.full_path)].contents,
                 file.contents, "The file #{@tmpdir["a/b/c/hello"].full_path} should appear in the output")
  end

  test "multiple files" do
    dir = @tmpdir.create_dir("a/b/c")
    files = rand(50).times.collect do |i|
      dir.create_file("hello-#{i}")
    end
    files.each { |f| f.write(rand(1000)) }

    @source.input(@tmpdir.full_path)
    @source.output(@output.full_path)

    files.each do |file|
      assert_equal(@output[File.join(".", file.full_path)].contents,
                   file.contents, "The file #{file.full_path} should appear in the output")
    end
  end

  test "single file with prefix" do
    prefix = @source.attributes[:prefix] = "/usr/local"
    file = @tmpdir["hello"]
    file.write "Hello world"
    @source.input(@tmpdir.full_path)

    @source.output(@output.full_path)

    expected_path = File.join(".", file.full_path)
    p @output.full_path
    p expected_path
    sleep 30
    assert_equal(@output[expected_path].contents,
                 file.contents, "The file #{@tmpdir["hello"].full_path} should appear in the output")
  end

  test "single file with prefix and chdir" do
    prefix = @source.attributes[:prefix] = "/usr/local"
    chdir = @source.attributes[:chdir] = @tmpdir.full_path
    file = @tmpdir["hello"]
    file.write "Hello world"
    @source.input(".") # since we chdir, copy the entire root
    @source.output(@output.full_path)

    # path relative to the @output directory.
    expected_path = File.join(".", prefix, file.name)
    assert_equal(@output[expected_path].contents,
                 file.contents, "The file #{@tmpdir["hello"].full_path} should appear in the output")
  end

end # describe FPM::Package::Dir
