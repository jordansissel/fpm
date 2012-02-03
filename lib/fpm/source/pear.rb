require "fpm/namespace"
require "fpm/source"
require "fileutils"
require "fpm/util"

class FPM::Source::Pear < FPM::Source
  def self.flags(opts, settings)
    opts.on("--package-prefix PREFIX",
            "Prefix for PEAR packages") do |package_prefix|
      settings.source[:package_prefix] = package_prefix
    end
  end # def flags

  def get_metadata
    @pear_package = @paths.first
    pear_cmd = "pear remote-info #{@pear_package}"
    self[:name] = %x{#{pear_cmd} | sed -ne '/^Package\s*/s/^Package\s*//p'}.chomp
    self[:version] = %x{#{pear_cmd} | sed -ne '/^Latest\s*/s/^Latest\s*//p'}.chomp
    self[:summary] = %x{#{pear_cmd} | sed -ne '/^Summary\s*/s/^Summary\s*//p'}.chomp
    if self[:settings][:package_prefix]
      self[:package_prefix] = self[:settings][:package_prefix]
    else
      self[:package_prefix] = "php-pear"
    end
	self[:name] = "#{self[:package_prefix]}-#{self[:name]}"
  end # def get_metadata

  def make_tarball!(tar_path, builddir)
    tmpdir = "#{tar_path}.dir"
    ::Dir.mkdir(tmpdir)
    safesystem("pear install -n -f -P #{tmpdir} #{@pear_package}")
	# Remove the stuff we don't want
	['.depdb', '.depdblock', '.filemap', '.lock'].each { |f| safesystem("find #{tmpdir} -type f -name '#{f}' -exec rm {} \\;") }
	# find exits non-zero even though it works, so we have to work around that
	safesystem("find #{tmpdir} -type d -name '.channel*' -exec rm -rf {} \\; 2>/dev/null; exit 0")
    tar(tar_path, '.', tmpdir)
    @paths = %x{find #{tmpdir} -mindepth 1 -maxdepth 1 -type d | sed -e 's:^#{tmpdir}:.:'}.split("\n")
    safesystem(*["gzip", "-f", tar_path])
  end

end # class FPM::Source::Gem
