require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"
require "open-uri"
require 'rexml/document'

class FPM::Package::PECL < FPM::Package

  option "--package-name-prefix", "PREFIX",
         "Name prefix for pear package", :default => "php-pecl"

  option "--site", "PECL_SITE",
         "URL of the PECL site.", :default => "http://pecl.php.net"

  option "--fix-name", :flag, "Should the target package name be prefixed?",
         :default => true

  private
  def input(package)
    if !program_in_path?("phpize")
      raise ExecutableNotFound.new("phpize")
    end

    package_with_nice_name = make_version(package, version)
    self.url = "#{attributes[:pecl_site]}/package/#{package}"
    self.name = fix_name(package)
    downloaded_file = download(package_with_nice_name)
    install_to_stage(package_with_nice_name)
  end # def input

  # Download package from PECL site
  def download(package)
    #binaryname = make_version(package, package_version)
    binaryurl = "#{attributes[:pecl_site]}/get/#{package}"
    @logger.info("Downloading package", :package => package,
                 :from => binaryurl)
    ::Dir.chdir(build_path) do
      return fake_wget(binaryurl, "#{package}.tgz")
    end
  end #download

  # Compile and install to staging directory
  def install_to_stage(package)
    @logger.info("Building package", :package => package,
                 :bp => build_path, :sp => staging_path)
    ::Dir.chdir(build_path) do
      safesystem("tar", "xzf", "#{package}.tgz")

      # Parse XML file and populate some meta data
      File.open("package.xml", "r") do |f|
        doc = REXML::Document.new(f)
        self.license = doc.elements["package"].elements["license"].text
        self.description = doc.elements["package"].elements["description"].text
      end

      # Configure, compile and copy to staging directory
      ::Dir.chdir(package) do
        safesystem("phpize")
        safesystem("./configure")
        safesystem("make")

        # Default directorys for extensions and configs
        ext_dir = safesystemout("php-config", "--extension-dir").chomp
        config_dir = "/tmp/php.d"
        safesystemout("php-config", "--configure-options").
            split(/\s+/).each do |line|
          if line.start_with?("--with-config-file-scan-dir")
            config_dir = line.sub("--with-config-file-scan-dir=", "")
            break
          end
        end

        @logger.debug("Config dir for this extension", :dir => config_dir)
        FileUtils.mkdir_p("#{staging_path}/#{ext_dir}")
        FileUtils.mkdir_p("#{staging_path}#{config_dir}")

        ::Dir.glob("modules/*.so") do |f|
          safesystem("strip", "-s", f)
          so_file = File.basename(f)
          so_file_on_stage = "#{staging_path}/#{ext_dir}/#{so_file}"
          FileUtils.cp f, so_file_on_stage
          File.chmod(0755, so_file_on_stage)

          config_file = "#{staging_path}#{config_dir}/#{so_file.
              gsub(".so", "")}.ini"
          File.open(config_file, "w") do |f|
            f.write("; Enable #{so_file.gsub(".so", "")} extension module\n")
            f.write("extension=#{so_file}\n")
          end
          File.chmod(0644, config_file)
          config_files << config_file
        end # ::Dir.glob("modules/*.so")

      end # ::Dir.chdir(package)
    end # ::Dir.chdir(build_path)

  end # install_to_stage

  # Makes package-version string, if version not provided,
  # goes to internet to find latest
  def make_version(package, package_version)
    if !package_version.nil?
      "#{package}-#{package_version}"
    else
      "#{package}-#{get_latest_version(package)}"
    end
  end # make_version

  def get_latest_version(package)
    self.version = URI.parse(
        "#{attributes[:pecl_site]}/rest/r/#{package}/latest.txt"
    ).read.chomp
  end # get_latest_version

  # Fake "wget" - need for file download
  def fake_wget(url, destination_file)
    File.open(destination_file, "wb") do |dst|
      open(url, 'rb') do |src|
        dst.write(src.read)
      end
    end
    return destination_file
  end # fake_wget

  # fix name?
  def fix_name(name)
    return [attributes[:pecl_package_name_prefix], name].join("-")
  end

  public(:input)

end # class FPM::Package::PECL