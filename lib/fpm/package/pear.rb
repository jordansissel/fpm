require "fpm/namespace"
require "fpm/package"
require "fileutils"
require "fpm/util"

class FPM::Package::PEAR < FPM::Package
  option "--package-prefix", "PREFIX",
    "Name prefix for python package", :default => "php-pear"

  def input(input_package)
    if !program_in_path?("pear")
      raise ExecutableNotFound.new("pear")
    end

    # Create a temporary config file
    @logger.debug("Creating pear config file")
    config = File.expand_path(build_path("pear.config"))
    installroot = attributes[:prefix] || "/usr/share"
    safesystem("pear", "config-create", staging_path(installroot), config)

    @logger.info("Fetching package information", :package => input_package)
    pear_cmd = "pear -c #{config} remote-info #{input_package}"
    name = %x{#{pear_cmd} | sed -ne '/^Package\s*/s/^Package\s*//p'}.chomp
    self.name = "#{attributes[:pear_package_prefix]}-#{name}"
    self.version = %x{#{pear_cmd} | sed -ne '/^Latest\s*/s/^Latest\s*//p'}.chomp
    self.description  = %x{#{pear_cmd} | sed -ne '/^Summary\s*/s/^Summary\s*//p'}.chomp

    @logger.info("Installing pear package", :package => input_package,
                  :directory => staging_path)
    ::Dir.chdir(staging_path) do
      safesystem("pear", "-c", config, "install", "-n", "-f", "-P", ".",
                 input_package)
    end
 
    # Remove the stuff we don't want
    delete_these = [".depdb", ".depdblock", ".filemap", ".lock", ".channel"]
    Find.find(staging_path) do |path|
      FileUtils.rm_r(path) if delete_these.include?(File.basename(path))
    end
  end # def input
end # class FPM::Package::PEAR
