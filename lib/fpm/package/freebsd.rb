require "backports" # gem backports
require "fpm/package"
require "fpm/util"
require "digest"
require "fileutils"

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
    # See https://github.com/jordansissel/fpm/issues/1090
    # require xz later, because this triggers a load of liblzma.so.5 that is
    # unavailable on older CentOS/RH distros.
    require "xz"
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

    # Follow similar rules to these used in ``to_s_fullversion`` method.
    # FIXME: maybe epoch should also be introduced somehow ("#{version},#{epoch})?
    #        should it go to pkgdata["version"] or to another place?
    # https://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html
    pkg_version = (iteration and (iteration.to_i > 0)) ?  "#{version}-#{iteration}" : "#{version}"

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
        FPM::Util::TarWriter.new(xz) do |tar|
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

  def to_s_extension; "txz"; end

  def to_s_fullversion()
    # iteration (PORTREVISION on FreeBSD) shall be appended only(?) if non-zero.
    # https://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html
    (iteration and (iteration.to_i > 0)) ?  "#{version}_#{iteration}" : "#{version}"
  end

  def to_s(format=nil)
    return super(format.nil? ? "NAME-FULLVERSION.EXTENSION" : format)
  end # def to_s
end # class FPM::Package::FreeBSD
