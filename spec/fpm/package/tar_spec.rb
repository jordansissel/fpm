require "spec_setup"
require "fpm" # local
require "English" # for $CHILD_STATUS

describe FPM::Package::Tar do
  before do
    subject.name = "name"
    subject.version = "123"
    subject.architecture = "all"
    subject.iteration = "100"
  end

  describe "#to_s" do
    it "should have a default output filename" do
      insist { subject.to_s "NAME-VERSION-ITERATION.ARCH.TYPE"} == "name-123-100.all.tar"
    end
  end # describe to_s

  context 'when extracted' do
    let(:target) { Stud::Temporary.pathname + ".tar" }
    let(:output_dir) { Stud::Temporary.directory }
    before do
      subject.output( target)
      system("tar x -C '#{output_dir}' -f #{target}")
      raise "couldn't extract test tar" unless $CHILD_STATUS.success?
    end

    it "doesn't include a .scripts folder" do
      insist { Dir.exist?(File.join(output_dir, '.scripts')) } == false
    end

    after do
      FileUtils.rm_rf(output_dir)
      FileUtils.rm_rf(target)
    end
  end
end # describe FPM::Package::Tar
