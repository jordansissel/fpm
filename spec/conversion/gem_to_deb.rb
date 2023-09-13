require "spec_setup"
require "fpm/command" # local
require "fpm/package/deb" # local
require "fpm/package/gem" # local
require "stud/temporary"

describe "-s gem -t deb" do
  # dpkg-deb lets us query deb package files.
  # Comes with debian and ubuntu systems.
  have_dpkg_deb = program_exists?("dpkg-deb")
  if !have_dpkg_deb
    Cabin::Channel.get("rspec") \
      .warn("Skipping some deb tests because 'dpkg-deb' isn't in your PATH")
  end

  let(:fpm) { FPM::Command.new("fpm") }

  let(:target) { Stud::Temporary.pathname + ".deb" }

  after do
    File.unlink(target) if File.exist?(target)
  end

  before do
    insist { fpm.run(["-s", "gem", "-t", "deb", "-p", target, "rails"]) } == 0
  end

  it "should have a correctly formatted Provides field" do
    deb = FPM::Package::Deb.new
    deb.input(target)

    # Converting gem->deb should format the deb Provides field as "rubygem-rails (= version)"
    insist { deb.provides.first } =~ /^rubygem-rails \(= \d+\.\d+\.\d+\)$/
  end

end # describe "-s gem -t deb"
