require "fpm/namespace"
require "fpm/source"
require "fileutils"

class FPM::Source::Npm < FPM::Source
  def get_source(params)
    @npm = @paths.first
  end # def get_source

  def download(npm_name, version=nil)
  end # def download

  def get_metadata
    # set self[:...] values
    # :name
    # :maintainer
    # :url
    # :category
    # :dependencies
  end # def get_metadata

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"
    installdir = "#{tmpdir}/#{::Gem::dir}"
    ::FileUtils.mkdir_p(installdir)
    args = ["gem", "install", "--quiet", "--no-ri", "--no-rdoc",
       "--install-dir", installdir, "--ignore-dependencies", @paths.first]
    system(*args)
    tar(tar_path, ".", tmpdir)

    # TODO(sissel): Make a helper method.
    system(*["gzip", "-f", tar_path])
  end

end # class FPM::Source::Gem
