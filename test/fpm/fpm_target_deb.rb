require 'rubygems'
require 'minitest/autorun'
require 'fpm/target/deb'
require 'fpm/source/dir'
require 'erb'

describe FPM::Target::Deb do
  it 'renders the control file template correctly' do
    # Use the 'dir' source as it is the simplest to test in isolation
    root = File.join(File.dirname(__FILE__), 'test_data')
    # paths = root = File.join(File.dirname(__FILE__), 'test_data')
    # FIXME: Should be a fully-specifed path, but needs
    # some fixes in the path handling to remove the root components.
    paths = './test_data/dir/'
    source = FPM::Source::Dir.new(paths, root)
    deb = FPM::Target::Deb.new(source)

    # Fix some properties of the package to get consistent output
    deb.scripts = {}
    deb.architecture = 'all'
    deb.maintainer = '<testdude@example.com>'

    # Render the template and compare it to our canned output
    control_output = deb.render_spec
    test_file = File.join(File.dirname(__FILE__), 'test_data', 'test_deb.control')
    file_output = File.read(test_file)
    control_output.must_equal file_output
  end
end
