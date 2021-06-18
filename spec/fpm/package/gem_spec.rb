require "spec_setup"
require "fpm" # local
require "fpm/package/gem" # local

have_gem = program_exists?("gem")
if !have_gem
  Cabin::Channel.get("rspec") \
    .warn("Skipping Gem#input tests because 'gem' isn't in your PATH")
end

describe FPM::Package::Gem do
  before do
    skip("Missing program 'gem'") unless program_exists?("gem")
  end

  let (:example_gem) do
    File.expand_path("../../fixtures/gem/example/example-1.0.gem", File.dirname(__FILE__))
  end

  after :each do
    subject.cleanup
  end

  context "when :gem_version_bins? is true" do
    before :each do
      subject.attributes[:gem_version_bins?] = true
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it "it should append the version to binaries" do
      subject.input(example_gem)
      insist { ::Dir.entries(File.join(subject.staging_path, "/usr/bin")) }.include?("example-1.0.0")
    end
  end

  context "when :gem_version_bins? is false" do
    before :each do
      subject.attributes[:gem_version_bins?] = false
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it "it should not append the version to binaries" do
      subject.input(example_gem)
      insist { ::Dir.entries(File.join(subject.staging_path, "/usr/bin")) }.include?("example")
    end

  end

  context "when :gem_fix_name? is true" do
    before :each do
      subject.attributes[:gem_fix_name?] = true
    end

    context "and :gem_package_name_prefix is nil/default" do
      it "should prefix the package with 'gem-'" do
        subject.input(example_gem)
        insist { subject.name } == "rubygem-example"
      end
    end

    context "and :gem_package_name_prefix is set" do
      it "should prefix the package name appropriately" do
        prefix = "whoa"
        subject.attributes[:gem_package_name_prefix] = prefix
        subject.input(example_gem)
        insist { subject.name } == "#{prefix}-example"
      end
    end
  end

  context "when :gem_fix_name? is false" do
    before :each do
      subject.attributes[:gem_fix_name?] = false
    end

    it "it should not prefix the name at all" do
      subject.input(example_gem)
      insist { subject.name } == "example"
    end
  end

  context "when :gem_shebang is nil/default" do
    before :each do
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it 'should not change the shebang' do
      subject.input(example_gem)
      file_path = File.join(subject.staging_path, '/usr/bin/example')
      insist { File.readlines(file_path).grep(/^#!\/usr\/bin\/env /).any? } == true
    end
  end

  context "when :gem_shebang is set" do
    before :each do
      subject.attributes[:gem_shebang] = '/opt/special/bin/ruby'
      subject.attributes[:gem_bin_path] = '/usr/bin'
    end

    it 'should change the shebang' do
      subject.input(example_gem)
      file_path = File.join(subject.staging_path, '/usr/bin/example')
      insist { File.readlines(file_path).grep("#!/opt/special/bin/ruby\n").any? } == true
    end
  end

  context "when confronted with a multiplicity of changelog formats" do
    # FIXME: don't expose RE's, provide a more stable interface

    it 'should recognize these formats' do
      r1 = Regexp.new(FPM::Package::Gem::P_RE_VERSION_DATE)
      r2 = Regexp.new(FPM::Package::Gem::P_RE_DATE_VERSION)
      [
        [ "cabin",       "v0.1.7 (2011-11-07)",       "0.1.7", "2011-11-07",       "1320624000" ],
        [ "chandler",    "## [0.7.0][] (2016-12-23)", "0.7.0", "2016-12-23",       "1482451200" ],
        [ "domain_name", "## [v0.5.20170404](https://github.com/knu/ruby-domain_name/tree/v0.5.20170404) (2017-04-04)", "0.5.20170404", "2017-04-04", "1491264000" ],
        [ "parseconfig", "Mon Jan 25, 2016 - v1.0.8", "1.0.8", "Mon Jan 25, 2016", "1453680000" ],
        [ "rack_csrf",   "# v2.6.0 (2016-12-31)",     "2.6.0", "2016-12-31",       "1483142400" ],
        [ "sinatra",     "= 1.4.7 / 2016-01-24",      "1.4.7", "2016-01-24",       "1453593600" ],
      ].each do |gem, line, version, date, unixdate|
        v = ""
        d = ""
        [r1, r2].each do |r|
          if r.match(line)
            d = $~[:date]
            v = $~[:version]
            break
          end
        end
        if (d == "")
           puts("RE failed to match for gem #{gem}, #{line}")
        end
        e = Date.parse(d)
        u = e.strftime("%s")
        insist { v } == version
        insist { d } == date
        insist { u } == unixdate
      end
    end
  end

end # describe FPM::Package::Gem
