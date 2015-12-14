require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"
require "backports"
require "fileutils"
require "digest"

# Support for debian packages (.deb files)
#
# This class supports both input and output of packages.
class FPM::Package::APK< FPM::Package

  # Map of what scripts are named.
  SCRIPT_MAP = {
    :before_install     => "pre-install",
    :after_install      => "post-install",
    :before_remove      => "pre-deinstall",
    :after_remove       => "post-deinstall",
  } unless defined?(SCRIPT_MAP)

  # The list of supported compression types. Default is gz (gzip)
  COMPRESSION_TYPES = [ "gz" ]

  private

  # Get the name of this package. See also FPM::Package#name
  #
  # This accessor actually modifies the name if it has some invalid or unwise
  # characters.
  def name
    if @name =~ /[A-Z]/
      logger.warn("apk packages should not have uppercase characters in their names")
      @name = @name.downcase
    end

    if @name.include?("_")
      logger.warn("apk packages should not include underscores")
      @name = @name.gsub(/[_]/, "-")
    end

    if @name.include?(" ")
      logger.warn("apk packages should not contain spaces")
      @name = @name.gsub(/[ ]/, "-")
    end

    return @name
  end # def name

  def prefix
    return (attributes[:prefix] or "/")
  end # def prefix

  def input(input_path)
    extract_info(input_path)
    extract_files(input_path)
  end # def input

  def extract_info(package)

    logger.error("Extraction is not yet implemented")
  end # def extract_info

  def extract_files(package)

    # unpack the data.tar.{gz,bz2,xz} from the deb package into staging_path
    safesystem("ar p #{package} data.tar.gz " \
               "| tar gz -xf - -C #{staging_path}")
  end # def extract_files

  def output(output_path)

    output_check(output_path)

    control_path = build_path("control")
    controltar_path = build_path("control.tar.gz")

    FileUtils.mkdir(control_path)

    # control tar.
    begin

      write_pkginfo(control_path)

      # scripts
      scripts = write_control_scripts(control_path)

      # zip it
      compress_control(control_path, controltar_path)
    ensure
      FileUtils.rm_r(control_path)
    end

    # data tar.
    begin
    ensure
    end

    # concatenate the two into a real apk.
    begin
    ensure
    end

    logger.warn("apk output to is not implemented")
  end

  def write_pkginfo(base_path)

    path = "#{base_path}/.PKGINFO"

    pkginfo_io = StringIO::new
    package_version = to_s("FULLVERSION")

    pkginfo_io << "pkgname = #{@name}\n"
    pkginfo_io << "pkgver = #{package_version}\n"
    pkginfo_io << "datahash = 123\n"

    File.write(path, pkginfo_io.string)
    `cp #{path} /tmp/.PKGINFO`
  end

  # Writes each control script from template into the build path,
  # in the folder given by [base_path]
  def write_control_scripts(base_path)

    scripts = ["pre-install",
                "post-install",
                "pre-deinstall",
                "post-deinstall",
                "pre-upgrade",
                "post-upgrade"
              ]

    scripts.each do |path|

      script_path = "#{base_path}/#{path}"
      File.write(script_path, template("apk/#{path}").result(binding))
    end
  end

  # Compresses the current contents of the given
  def compress_control(path, target_path)

    args = [ tar_cmd, "-C", path, "-zcf", target_path,
      "--owner=0", "--group=0", "--numeric-owner", "." ]
    safesystem(*args)

    `cp #{target_path} /tmp/control.tar.gz`
  end

  def to_s(format=nil)
    return super("NAME_FULLVERSION_ARCH.TYPE") if format.nil?
    return super(format)
  end

  public(:input, :output, :architecture, :name, :prefix, :converted_from, :to_s)
end
