require "fpm/package"
require "backports"
require "fileutils"
require "find"
require "rpm" # gem 'rpm'
require "rpm/file"

class FPM::Package::RPM < FPM::Package
  private

  def <<(path)
    rpm = ::RPM::File.new(path)

    tags = {}
    rpm.header.tags.each do |tag|
      tags[tag.tag] = tag.value
    end

    # For all meaningful tags, set package metadata
    # TODO(sissel): find meaningful tags

    # Extract to the staging directory
    rpm.extract(staging_path)
  end # def <<

  def output(dir)
  end

  public(:<<, :output)
end # class FPM::Package::Dir
