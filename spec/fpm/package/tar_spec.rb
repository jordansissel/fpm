require "spec_setup"
require "fpm" # local
require "fpm/package/tar" # local
require "stud/temporary"

describe FPM::Package::Tar do
  let(:tmpdir) { Stud::Temporary.directory("tmpdir") }
  let(:pkg) { Stud::Temporary.directory("pkg") }

  let(:tar) {
    File.join(tmpdir, "foo.tar")
  }

  let(:tar_gz) {
    "#{tar}.gz".tap { |path| `gzip #{tar}` }
  }

  let(:foo_file) { File.join(pkg, "foo.txt") }

  before :each do
    File.open(foo_file, 'w') {|f| f.puts("foo") }
    `tar -C #{pkg} -cf #{tar} .`
  end

  after :each do
    subject.cleanup
    FileUtils.rm_r(tmpdir)
    FileUtils.rm_r(pkg)
  end # after

  it "can package a simple tar file guessing package name from the tar file's name" do
    subject.input(tar)

    insist { subject.name } == "foo"
    insist { File.read(File.join(subject.staging_path, "foo.txt")) } == "foo\n"
  end

  it "can package a compressed tar file" do
    subject.input(tar_gz)

    insist { File.read(File.join(subject.staging_path, "foo.txt")) } == "foo\n"
  end

  it "can package a tar file and add a prefix" do
    subject.attributes[:prefix] = 'opt'
    subject.input(tar)

    insist { File.read(File.join(subject.staging_path, "opt", "foo.txt")) } == "foo\n"
  end

  it "supplying --prefix and --exclude does not cause an error (fpm#1151)" do
    subject.attributes[:excludes] = ['foo.txt']
    subject.attributes[:prefix] = ['opt']
    # this does not do the exclusion, but does (did) trigger the exclusion code that chokes :/
    subject.input(tar)
  end

end
