require "backports" # gem backports
require "fpm/package"
require "fpm/util"
require "digest"
require "fileutils"
require "rubygems/package"
require "xz"

class FPM::Package::FreeBSD < FPM::Package
  SCRIPT_MAP = {
    :before_install     => "pre-install",
    :after_install      => "post-install",
    :before_remove      => "pre-deinstall",
    :after_remove       => "post-deinstall",
  } unless defined?(SCRIPT_MAP)

  def self.default_abi
    abi_name = %x{uname -s}.chomp
    abi_version = %x{uname -r}.chomp.split(".")[0]
    abi_arch = %x{uname -m}.chomp

    [abi_name, abi_version, abi_arch].join(":")
  end

  option "--abi", "ABI",
         "Sets the FreeBSD abi pkg field to specify binary compatibility.",
         :default => default_abi

  option "--origin", "ABI",
         "Sets the FreeBSD 'origin' pkg field",
         :default => "fpm/<name>"

  def output(output_path)
    output_check(output_path)

    # Build the packaging metadata files.
    checksums = {}
    self.files.each do |f|
      path = staging_path(f)
      if File.symlink?(path)
        checksums[f] = "-"
      elsif File.file?(path)
        checksums[f] = Digest::SHA256.file(path).hexdigest
      end
    end

    pkg_origin = attributes[:freebsd_origin]
    if pkg_origin == "fpm/<name>"  # fill in default
      pkg_origin = "fpm/#{name}"
    end

    pkg_version = "#{version}-#{iteration || 1}"

    pkgdata = {
      "abi" => attributes[:freebsd_abi],
      "name" => name,
      "version" => pkg_version,
      "comment" => description,
      "desc" => description,
      "origin" => pkg_origin,
      "maintainer" => maintainer,
      "www" => url,
      # prefix is required, but it doesn't seem to matter
      "prefix" => "/",
    }

    # Write +COMPACT_MANIFEST, without the "files" section.
    File.open(staging_path("+COMPACT_MANIFEST"), "w+") do |file|
      file.write(pkgdata.to_json + "\n")
    end

    # Populate files + checksums, then write +MANIFEST.
    pkgdata["files"] = {}
    checksums.each do |f, shasum|
      # pkg expands % URL-style escapes, so make sure to escape % as %25
      pkgdata["files"]["/" + f.gsub("%", "%25")] = shasum
    end

    # Populate scripts
    pkgdata["scripts"] = {}
    scripts.each do |name, data|
      pkgdata["scripts"][SCRIPT_MAP[name]] = data
    end

    File.open(staging_path("+MANIFEST"), "w+") do |file|
      file.write(pkgdata.to_json + "\n")
    end

    # Create the .txz package archive from the files in staging_path.
    File.open(output_path, "wb") do |file|
      XZ::StreamWriter.new(file) do |xz|
        ::Gem::Package::TarWriter.new(xz) do |tar|
          # The manifests must come first for pkg.
          add_path(tar, "+COMPACT_MANIFEST",
                   File.join(staging_path, "+COMPACT_MANIFEST"))
          add_path(tar, "+MANIFEST",
                   File.join(staging_path, "+MANIFEST"))

          checksums.keys.each do |path|
            add_path(tar, "/" + path, File.join(staging_path, path))
          end
        end
      end
    end
  end # def output

  def add_path(tar, tar_path, path)
    stat = File.lstat(path)
    if stat.directory?
      tar.mkdir(tar_path, stat.mode)
    elsif stat.symlink?
      tar.add_symlink(tar_path, File.readlink(path), stat.mode)
    else
      tar.add_file_simple(tar_path, stat.mode, stat.size) do |io|
        File.open(path) do |fd|
          chunk = nil
          size = 0
          while chunk = fd.read(16384) do
            size += io.write(chunk)
          end
          if size != stat.size
            raise "Failed to add #{path} to the archive; expected to " +
                  "write #{stat.size} bytes, only wrote #{size}"
          end
        end
      end # tar.tar.add_file_simple
    end
  end # def add_path

  def to_s(format=nil)
    return "#{name}-#{version}_#{iteration || 1}.txz"
    return super(format)
  end # def to_s
end # class FPM::Package::FreeBSD

# Backport Symlink Support to TarWriter
# https://github.com/rubygems/rubygems/blob/4a778c9c2489745e37bcc2d0a8f12c601a9c517f/lib/rubygems/package/tar_writer.rb#L239-L253
module TarWriterAddSymlink
  refine Gem::Package::TarWriter do
    def add_symlink(name, target, mode)
      check_closed

      name, prefix = split_name name

      header = Gem::Package::TarHeader.new(:name => name, :mode => mode,
                                           :size => 0, :typeflag => "2",
                                           :linkname => target,
                                           :prefix => prefix,
                                           :mtime => Time.now).to_s

      @io.write header

      self
    end # def add_symlink
  end # refine Gem::Package::TarWriter
end # module TarWriterAddSymlink

module Util
  module Tar
    unless Gem::Package::TarWriter.public_instance_methods.include? :add_symlink
      using TarWriterAddSymlink
    end
  end # module Tar
end # module Util
