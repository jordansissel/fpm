require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"
require "backports"
require "fileutils"
require "digest"
require 'digest/sha1'

# Support for debian packages (.deb files)
#
# This class supports both input and output of packages.
class FPM::Package::APK< FPM::Package

  TAR_CHUNK_SIZE = 512
  TAR_TYPEFLAG_OFFSET = 156
  TAR_LENGTH_OFFSET_START = 124
  TAR_LENGTH_OFFSET_END = 135


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
    controltar_path = build_path("control.tar")
    datatar_path = build_path("data.tar")

    FileUtils.mkdir(control_path)

    # data tar.
    tar_path(staging_path(""), datatar_path)

    # control tar.
    begin
      write_pkginfo(control_path)
      write_control_scripts(control_path)
      tar_path(control_path, controltar_path)
    ensure
      FileUtils.rm_r(control_path)
    end

    # concatenate the two into a real apk.
    begin

      # cut end-of-tar record from control tar
      cut_tar_record(controltar_path)

      # calculate/rewrite sha1 hashes for data tar
      hash_datatar(datatar_path)

      # concatenate the two into the final apk
      concat_zip_tars(controltar_path, datatar_path, output_path)
    ensure
      logger.warn("apk output to is not implemented")
      `rm -rf /tmp/apkfpm`
      `cp -r #{build_path("")} /tmp/apkfpm`
    end
  end

  def write_pkginfo(base_path)

    path = "#{base_path}/.PKGINFO"

    pkginfo_io = StringIO::new
    package_version = to_s("FULLVERSION")

    pkginfo_io << "pkgname = #{@name}\n"
    pkginfo_io << "pkgver = #{package_version}\n"

    File.write(path, pkginfo_io.string)
  end

  # Writes each control script from template into the build path,
  # in the folder given by [base_path]
  def write_control_scripts(base_path)

    scripts =
    [
      "pre-install",
      "post-install",
      "pre-deinstall",
      "post-deinstall",
      "pre-upgrade",
      "post-upgrade"
    ]

    scripts.each do |path|

      script_path = "#{base_path}/.#{path}"
      File.write(script_path, template("apk/#{path}").result(binding))
    end
  end

  # Removes the end-of-tar records from the given [target_path].
  # End of tar records are two contiguous empty tar records at the end of the file
  # Taken together, they comprise 1k of null data.
  def cut_tar_record(target_path)

    record_length = 0
    contiguous_records = 0
    desired_tar_length = 0

    # Scan to find the location of the two contiguous null records
    open(target_path, "rb") do |file|

      until(contiguous_records == 2)

        # skip to header length
        file.read(124)

        ascii_length = file.read(12)
        if(file.eof?())
          raise StandardError.new("Invalid tar stream, eof before end-of-tar record")
        end

        record_length = ascii_length.to_i(8)

        if(record_length == 0)
          contiguous_records += 1
        else
          # If there was a previous null tar, add its header length too.
          if(contiguous_records != 0)
            desired_tar_length += TAR_CHUNK_SIZE
          end

          # tarballs work in 512-byte blocks, round up to the nearest block.
          record_length = determine_record_length(record_length)

          # reset, add length of content and header.
          contiguous_records = 0
          desired_tar_length += record_length + TAR_CHUNK_SIZE
        end

        # finish off the read of the header length
        file.read(376)

        # skip content of record
        file.read(record_length)
      end
    end

    # Truncate file
    if(desired_tar_length <= 0)
      raise StandardError.new("Unable to trim apk control tar")
    end

    File.truncate(target_path, desired_tar_length)
  end

  # Rewrites the tar file located at the given [target_tar_path]
  # to have its record headers use a simple checksum,
  # and the apk sha1 hash extension.
  def hash_datatar(target_path)

    header = extension_header = ""
    data = extension_data = ""
    record_length = extension_length = 0
    empty_records = 0

    temporary_file_name = target_path + "~"

    target_file = open(temporary_file_name, "wb")
    file = open(target_path, "rb")
    begin

      until(file.eof?() || empty_records == 2)

        header = file.read(TAR_CHUNK_SIZE)
        typeflag = header[TAR_TYPEFLAG_OFFSET]
        record_length = header[TAR_LENGTH_OFFSET_START..TAR_LENGTH_OFFSET_END].to_i(8)

        data = ""
        record_length = determine_record_length(record_length)

        until(data.length == record_length)
          data += file.read(TAR_CHUNK_SIZE)
        end

        # If it's not a null record, do extension hash.
        if(typeflag != "\0")
          extension_header = header.dup()

          # hash data contents with sha1, if there is any content.
          if(typeflag == '5')
            extension_data = ""
          else
            extension_data = hash_record(data)
          end

          extension_header[TAR_TYPEFLAG_OFFSET] = 'x'
          extension_header[TAR_LENGTH_OFFSET_START..TAR_LENGTH_OFFSET_END] = extension_data.length.to_s(8).rjust(12, '0')
          extension_header = checksum_header(extension_header)

          # write extension record
          target_file.write(extension_header)
          target_file.write(extension_data)
        else
          empty_records += 1
        end

        # write header and data to target file.
        target_file.write(header)
        target_file.write(data)
      end
      FileUtils.mv(temporary_file_name, target_path)
    ensure
      file.close()
      target_file.close()
    end
  end

  # Concatenates each of the given [apath] and [bpath] into the given [target_path]
  def concat_zip_tars(apath, bpath, target_path)

    temp_apath = apath + "~"
    temp_bpath = bpath + "~"

    # zip each path separately
    Zlib::GzipWriter.open(temp_apath) do |target_writer|
      open(apath, "rb") do |file|
        until(file.eof?())
          target_writer.write(file.read(4096))
        end
      end
    end

    Zlib::GzipWriter.open(temp_bpath) do |target_writer|
      open(bpath, "rb") do |file|
        until(file.eof?())
          target_writer.write(file.read(4096))
        end
      end
    end

    # concat both into one.
    File.open(target_path, "wb") do |target_writer|
      open(temp_apath, "rb") do |file|
        until(file.eof?())
          target_writer.write(file.read(4096))
        end
      end
      open(temp_bpath, "rb") do |file|
        until(file.eof?())
          target_writer.write(file.read(4096))
        end
      end
    end
  end

  # Rounds the given [record_length] to the nearest highest evenly-divisble number of 512.
  def determine_record_length(record_length)

    if(record_length % 512 != 0)
      record_length = (record_length + 511) & ~511;
    end
    return record_length
  end

  # Checksums the entire contents of the given [header]
  # Writes the resultant checksum into indices 148-155 of the same [header],
  # and returns the modified header.
  # 148-155 is the "size" range in a tar/ustar header.
  def checksum_header(header)

    # blank out header checksum
    for i in 148..155
      header[i] = ' '
    end

    # calculate new checksum
    checksum = 0

    for i in 0..511
      checksum += header.getbyte(i)
    end

    checksum = checksum.to_s(8).rjust(8, '0')
    header[148..155] = checksum
    return header
  end

  # SHA-1 hashes the given data, then places it in the APK hash string format
  # then returns.
  def hash_record(data)

    # %u %s=%s\n
    # len name=hash

    hash = Digest::SHA1.hexdigest(data)
    name = "APK-TOOLS.checksum.SHA1"

    ret = "#{name}=#{hash}\n"

    # the length requirement needs to know its own length too, because the length
    # is the entire length of the line, not just the contents.
    length = ret.length
    line_length = length.to_s
    length += line_length.length
    candidate_ret = "#{line_length} #{ret}"

    if(candidate_ret.length != length)
      length += 1
      candidate_ret = "#{length.to_s} #{ret}"
    end

    ret = candidate_ret

    # pad out the result
    until(ret.length % 512 == 0)
      ret << "\0"
    end
    return ret
  end

  # Tars the current contents of the given [path] to the given [target_path].
  def tar_path(path, target_path)

    # Change directory to the source path, and glob files
    # This is done so that we end up with a "flat" archive, that doesn't
    # have any path artifacts from the packager's absolute path.
    File::Dir::chdir(path) do
      entries = File::Dir::glob("**", File::FNM_DOTMATCH)

      args =
      [
        tar_cmd,
        "-f",
        target_path,
        "-c"
      ]

      entries.each do |entry|
        unless(entry == '..' || entry == '.')
          args = args << entry
        end
      end

      safesystem(*args)
    end
  end

  def to_s(format=nil)
    return super("NAME_FULLVERSION_ARCH.TYPE") if format.nil?
    return super(format)
  end

  public(:input, :output, :architecture, :name, :prefix, :converted_from, :to_s)
end
