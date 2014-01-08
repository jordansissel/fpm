require 'fpm/namespace'
require 'fpm/package'
require 'fpm/util'
require 'fileutils'
require 'open-uri'
require 'rexml/document'

# PECL package support for FPM
class FPM::Package::PECL < FPM::Package

  option '--package-name-prefix', 'PREFIX',
         'Name prefix for pear package', :default => 'php-pecl'

  option '--site', 'PECL_SITE',
         'URL of the PECL site.', :default => 'http://pecl.php.net'

  option '--fix-name', :flag, 'Should the target package name be prefixed?',
         :default => true

  def input(package)
    if !program_in_path?('phpize')
      raise ExecutableNotFound.new('phpize')
    end

    package_with_nice_name = make_version(package, version)
    self.url = "#{attributes[:pecl_site]}/package/#{package}"
    self.name = fix_name(package)
    download(package_with_nice_name)
    install_to_stage(package_with_nice_name)
  end

  private

  def download(package)
    binaryurl = "#{attributes[:pecl_site]}/get/#{package}"

    @logger.info(
        'Downloading package',
        :package => package,
        :from => binaryurl
    )

    ::Dir.chdir(build_path) do
      return fake_wget(binaryurl, "#{package}.tgz")
    end
  end

  def install_to_stage(package)
    @logger.info('Building package',
                 :package => package,
                 :bp => build_path,
                 :sp => staging_path)
    ::Dir.chdir(build_path) do
      safesystem('tar', 'xzf', "#{package}.tgz")

      # Parse XML file and populate some meta data
      File.open('package.xml', 'r') do |package_f|
        doc = REXML::Document.new(package_f)
        self.license = doc.elements['package'].elements['license'].text
        self.description = doc.elements['package'].elements['description'].text
      end

      # Configure, compile and copy to staging directory
      ::Dir.chdir(package) do
        safesystem('phpize')
        safesystem('./configure')
        safesystem('make')

        # Default directorys for extensions and configs
        ext_dir = safesystemout('php-config', '--extension-dir').chomp
        config_dir = '/tmp/php.d'
        safesystemout('php-config', '--configure-options')
        .split(/\s+/).each do |line|
          if line.start_with?('--with-config-file-scan-dir')
            config_dir = line.sub('--with-config-file-scan-dir=', '')
            break
          end
        end

        @logger.debug('Config dir for this extension', :dir => config_dir)
        FileUtils.mkdir_p("#{staging_path}/#{ext_dir}")
        FileUtils.mkdir_p("#{staging_path}#{config_dir}")

        ::Dir.glob('modules/*.so') do |fh|
          safesystem('strip', '-s', fh)
          so_file = File.basename(fh)
          so_file_on_stage = "#{staging_path}/#{ext_dir}/#{so_file}"
          FileUtils.cp fh, so_file_on_stage
          File.chmod(0755, so_file_on_stage)

          config_file =
              "#{staging_path}#{config_dir}/#{so_file.gsub('.so', '')}.ini"
          File.open(config_file, 'w') do |f|
            f.write("; Enable #{so_file.gsub('.so', '')} extension module\n")
            f.write("extension=#{so_file}\n")
          end
          File.chmod(0644, config_file)
          config_files << config_file
        end # ::Dir.glob("modules/*.so")

      end # ::Dir.chdir(package)
    end # ::Dir.chdir(build_path)

  end

  def make_version(package, package_version)
    if !package_version.nil?
      "#{package}-#{package_version}"
    else
      "#{package}-#{get_latest_version(package)}"
    end
  end

  def get_latest_version(package)
    self.version = URI.parse(
        "#{attributes[:pecl_site]}/rest/r/#{package}/latest.txt"
    ).read.chomp
  end

  def fake_wget(url, destination_file)
    File.open(destination_file, 'wb') do |dst|
      open(url, 'rb') do |src|
        dst.write(src.read)
      end
    end
    destination_file
  end

  def fix_name(name)
    [attributes[:pecl_package_name_prefix], name].join('-')
  end

end  # end FPM::Package::PECL
