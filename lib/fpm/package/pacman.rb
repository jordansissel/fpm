# -*- coding: utf-8 -*-
require "fpm/package"
require "fpm/util"
require "backports/latest"
require "fileutils"
require "find"

class FPM::Package::Pacman < FPM::Package

  option "--optional-depends", "PACKAGE",
    "Add an optional dependency to the pacman package.", :multivalued => true

  option "--use-file-permissions", :flag,
    "Use existing file permissions when defining ownership and modes"

  option "--user", "USER", "The owner of files in this package", :default => 'root'

  option "--group", "GROUP", "The group owner of files in this package", :default => 'root'

  # The list of supported compression types. Default is xz (LZMA2)
  COMPRESSION_TYPES = [ "gz", "bzip2", "xz", "zstd", "none" ]

  option "--compression", "COMPRESSION", "The compression type to use, must " \
    "be one of #{COMPRESSION_TYPES.join(", ")}.", :default => "zstd" do |value|
    if !COMPRESSION_TYPES.include?(value)
      raise ArgumentError, "Pacman compression value of '#{value}' is invalid. " \
        "Must be one of #{COMPRESSION_TYPES.join(", ")}"
    end
    value
  end

  def initialize(*args)
    super(*args)
    attributes[:pacman_optional_depends] = []
  end # def initialize

  def architecture
    case @architecture
      when nil
        return %x{uname -m}.chomp   # default to current arch
      when "amd64" # debian and pacman disagree on architecture names
        return "x86_64"
      when "native"
        return %x{uname -m}.chomp   # 'native' is current arch
      when "all", "any", "noarch"
        return "any"
      else
        return @architecture
    end
  end # def architecture

  def iteration
    return @iteration || 1
  end # def iteration

  def config_files
    return @config_files || []
  end # def config_files

  def dependencies
    bogus_regex = /[^\sA-Za-z0-9><=+._@-]/
    # Actually modifies depencies if they are not right
    bogus_dependencies = @dependencies.grep bogus_regex
    if bogus_dependencies.any?
      @dependencies.reject! { |a| a =~ bogus_regex }
      logger.warn("Some of the dependencies looked like they weren't package " \
                  "names. Such dependency entries only serve to confuse arch. " \
                  "I am removing them.",
                  :removed_dependencies => bogus_dependencies,
                  :fixed_dependencies => @dependencies)
    end
    return @dependencies
  end


  # This method is invoked on a package when it has been converted to a new
  # package format. The purpose of this method is to do any extra conversion
  # steps, like translating dependency conditions, etc.
  #def converted_from(origin)
    # nothing to do by default. Subclasses may implement this.
    # See the RPM package class for an example.
  #end # def converted_from

  # Add a new source to this package.
  # The exact behavior depends on the kind of package being managed.
  #
  # For instance:
  #
  # * for FPM::Package::Dir, << expects a path to a directory or files.
  # * for FPM::Package::RPM, << expects a path to an rpm.
  #
  # The idea is that you can keep pumping in new things to a package
  # for later conversion or output.
  #
  # Implementations are expected to put files relevant to the 'input' in the
  # staging_path
  def input(pacman_pkg_path)
    control = {}
    # Unpack the control tarball
    safesystem(tar_cmd, "-C", staging_path, "-xf", pacman_pkg_path)
    pkginfo = staging_path(".PKGINFO")
    mtree = staging_path(".MTREE")
    install = staging_path(".INSTALL")

    control_contents = File.read(pkginfo)
    FileUtils.rm(pkginfo)
    FileUtils.rm(mtree)


    control_lines = control_contents.split("\n")
    control_lines.each do |line|
      key, val = line.split(/ += +/, 2)
      if control.has_key? key
        control[key].push(val)
      else
        control[key] = [val]
      end
    end

    self.name = control["pkgname"][0]

    # Parse 'epoch:version-iteration' in the version string
    version_re = /^(?:([0-9]+):)?(.+?)(?:-(.*))?$/
    m = version_re.match(control["pkgver"][0])
    if !m
      raise "Unsupported version string '#{control["pkgver"][0]}'"
    end
    self.epoch, self.version, self.iteration = m.captures

    self.maintainer = control["packager"][0]

    # Arch has no notion of vendor, so...
    #self.vendor =

    self.url = control["url"][0]
    # Groups could include more than one.
    # Speaking of just taking the first entry of the field:
    # A crude thing to do, but I suppose it's better than nothing.
    # -- Daniel Haskin, 3/24/2015
    self.category = control["group"] && control["group"][0] || self.category

    # Licenses could include more than one.
    # Speaking of just taking the first entry of the field:
    # A crude thing to do, but I suppose it's better than nothing.
    # -- Daniel Haskin, 3/24/2015
    self.license = control["license"][0] || self.license

    self.architecture = control["arch"][0]

    self.dependencies = control["depend"] || self.dependencies

    self.provides = control["provides"] || self.provides

    self.conflicts = control["conflict"] || self.conflicts

    self.replaces = control["replaces"] || self.replaces

    self.description = control["pkgdesc"][0]

    if control.include? "backup"
      self.config_files = control["backup"].map{|file| "/" + file}
    else
      self.config_files = []
    end

    self.dependencies = control["depend"] || self.dependencies
    
    if attributes[:no_auto_depends?]
      self.dependencies = []
    end

    self.attributes[:pacman_optional_depends] = control["optdepend"] || []
    # There are other available attributes, but I didn't include them because:
    # - makedepend: deps needed to make the arch package. But it's already
    #   made. It just needs to be converted at this point
    # - checkdepend: See above
    # - makepkgopt: See above
    # - size: can be dynamically generated
    # - builddate: Should be changed to time of package conversion in the new
    #   package, so this value should be thrown away.

    if File.exist?(install)
      functions = parse_install_script(install)
      if functions.include?("pre_install")
        self.scripts[:before_install] = functions["pre_install"].join("\n")
      end
      if functions.include?("post_install")
        self.scripts[:after_install] = functions["post_install"].join("\n")
      end
      if functions.include?("pre_upgrade")
        self.scripts[:before_upgrade] = functions["pre_upgrade"].join("\n")
      end
      if functions.include?("post_upgrade")
        self.scripts[:after_upgrade] = functions["post_upgrade"].join("\n")
      end
      if functions.include?("pre_remove")
        self.scripts[:before_remove] = functions["pre_remove"].join("\n")
      end
      if functions.include?("post_remove")
        self.scripts[:after_remove] = functions["post_remove"].join("\n")
      end
      FileUtils.rm(install)
    end

    # Note: didn't use `self.directories`.
    # Pacman doesn't really record that information, to my knowledge.

  end # def input

  def compression_option
    case self.attributes[:pacman_compression]
      when nil, "zstd"
        return "--zstd"
      when "none"
        return ""
      when "gz"
        return "-z"
      when "xz"
        return "--xz"
      when "bzip2"
        return "-j"
      when "zstd"
        return "--zstd"
      else
        return "--zstd"
      end
  end

  def compression_ending
    case self.attributes[:pacman_compression]
      when nil, "zstd"
        return ".zst"
      when "none"
        return ""
      when "gz"
        return ".gz"
      when "xz"
        return ".xz"
      when "bzip2"
        return ".bz2"
      when "zstd"
        return ".zst"
      else
        return ".zst"
      end
  end

  # Output this package to the given path.
  def output(output_path)
    output_check(output_path)

    # Copy all files from staging to BUILD dir
    Find.find(staging_path) do |path|
      src = path.gsub(/^#{staging_path}/, '')
      dst = build_path(src)
      begin
        copy_entry(path, dst, preserve=true, remove_destination=true)
      rescue
        copy_entry(path, dst, preserve=false, remove_destination=true)
      end
      copy_metadata(path, dst)
    end

    # This value is used later in the template for PKGINFO
    size = safesystemout("du", "-sk", build_path).split(/\s+/)[0].to_i * 1024
    builddate = Time.new.to_i

    pkginfo = template("pacman.erb").result(binding)
    pkginfo_file = build_path(".PKGINFO")
    File.write(pkginfo_file, pkginfo)

    if script?(:before_install) or script?(:after_install) or \
        script?(:before_upgrade) or script?(:after_upgrade) or \
        script?(:before_remove) or script?(:after_remove)
      install_script = template("pacman/INSTALL.erb").result(binding)
      install_script_file = build_path(".INSTALL")
      File.write(install_script_file, install_script)
    end

    generate_mtree

    File.expand_path(output_path).tap do |path|
      ::Dir.chdir(build_path) do
        safesystem(*([tar_cmd,
                      compression_option,
                      "-cf",
                      path] + data_tar_flags + \
                      ::Dir.entries(".").reject{|entry| entry =~ /^\.{1,2}$/ }))
      end
    end
  end # def output

  def data_tar_flags
    data_tar_flags = []
    if attributes[:pacman_use_file_permissions?].nil?
      if !attributes[:pacman_user].nil?
        if attributes[:pacman_user] == 'root'
          data_tar_flags += [ "--numeric-owner", "--owner", "0" ]
        else
          data_tar_flags += [ "--owner", attributes[:deb_user] ]
        end
      end

      if !attributes[:pacman_group].nil?
        if attributes[:pacman_group] == 'root'
          data_tar_flags += [ "--numeric-owner", "--group", "0" ]
        else
          data_tar_flags += [ "--group", attributes[:deb_group] ]
        end
      end
    end
    return data_tar_flags
  end # def data_tar_flags

  def default_output
    v = version
    v = "#{epoch}:#{v}" if epoch
    if iteration
      "#{name}_#{v}-#{iteration}_#{architecture}.#{type}"
    else
      "#{name}_#{v}_#{architecture}.#{type}"
    end
  end # def default_output

  def to_s_extension; "pkg.tar#{compression_ending}"; end

  def to_s(format=nil)
    # Default format if nil
    # git_1.7.9.3-1-amd64.pkg.tar.xz
    return super(format.nil? ? "NAME-FULLVERSION-ARCH.EXTENSION" : format)
  end # def to_s

  private

  def generate_mtree
    ::Dir.chdir(build_path) do
      cmd = "LANG=C bsdtar "
      cmd += "-czf .MTREE "
      cmd += "--format=mtree "
      cmd += "--options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' "
      cmd += ::Dir.entries(".").reject{|entry| entry =~ /^\.{1,2}$/ }.join(" ")
      safesystem(cmd)
    end
  end # def generate_mtree

  # KNOWN ISSUE:
  # If an un-matched bracket is used in valid bash, as in
  # `echo "{"`, this function will choke.
  # However, to cover this case basically
  # requires writing almost half a bash parser,
  # and it is a very small corner case.
  # Otherwise, this approach is very robust.
  def gobble_function(cons,prod)
    level = 1
    while level > 0
      line = cons.next
      # Not the best, but pretty good
      # short of writing an *actual* sh
      # parser
      level += line.count "{"
      level -= line.count "}"
      if level > 0
        prod.push(line.rstrip())
      else
        fine = line.sub(/\s*[}]\s*$/, "")
        if !(fine =~ /^\s*$/)
          prod.push(fine.rstrip())
        end
      end
    end
  end # def gobble_function

  FIND_SCRIPT_FUNCTION_LINE =
    /^\s*(\w+)\s*\(\s*\)\s*\{\s*([^}]+?)?\s*(\})?\s*$/

  def parse_install_script(path)
    global_lines = []
    look_for = Set.new(["pre_install", "post_install",
                        "pre_upgrade", "post_upgrade",
                        "pre_remove", "post_remove"])
    functions = {}
    look_for.each do |fname|
      functions[fname] = []
    end

    open(path, "r") do |iscript|
      lines = iscript.each
      begin
        while true
          line = lines.next
          # This regex picks up beginning names of posix shell
          # functions
          # Examples:
          #   fname() {
          #   fname() { echo hi }
          m = FIND_SCRIPT_FUNCTION_LINE.match(line)
          if not m.nil? and look_for.include? m[1]
            if not m[2].nil?
              functions[m[1]].push(m[2].rstrip())
            end
            gobble_function(lines, functions[m[1]])
          else
            global_lines.push(line.rstrip())
          end
        end
      rescue StopIteration
      end
    end
    look_for.each do |name|
      # Add global lines to each function to preserve global variables, etc.
      functions[name] = global_lines + functions[name]
    end
    return functions
  end # def parse_install_script
end # class FPM::Package::Pacman
