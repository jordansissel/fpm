require 'rubygems'
require 'minitest/autorun'
require 'fpm/target/rpm'
require 'fpm/source/dir'
require 'erb'

describe FPM::Target::Rpm do
  it 'renders the spec file template correctly' do
    # Use the 'dir' source as it is the simplest to test in isolation
    root = File.join(File.dirname(__FILE__), 'test_data')
    # paths = root = File.join(File.dirname(__FILE__), 'test_data')
    # FIXME: Should be a fully-specifed path, but needs
    # some fixes in the path handling to remove the root components.
    paths = './test_data/dir/'
    source = FPM::Source::Dir.new(paths, root)
    rpm = FPM::Target::Rpm.new(source)

    # Fix some properties of the package to get consistent output
    rpm.scripts = {}
    rpm.architecture = 'all'

    # Render the template and compare it to our canned output
    spec_output = rpm.render_spec
    test_file = File.join(File.dirname(__FILE__), 'test_data', 'test_rpm.spec')
    file_output = File.read(test_file)
    spec_output.must_equal file_output
  end
end
