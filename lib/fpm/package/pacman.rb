# -*- coding: utf-8 -*-
require "fpm/package"
require "backports"
require "fileutils"
require "find"

class FPM::Package::Pacman < FPM::Package

  DIGEST_ALGORITHMS = [
    "md5",
    "sha1",
    "sha224",
    "sha256",
    "sha384",
    "sha512"
  ] unless defined?(DIGEST_ALGORITHMS)

  option "--user", "USER", "Set the user to USER in the %files section. Overrides the user when used with use-file-permissions setting."

  option "--group", "GROUP", "Set the group to GROUP in the %files section. Overrides the group when used with use-file-permissions setting."

  option "--digest", DIGEST_ALGORITHMS.join("|"),
    "Select a digest algorithm. The algorithm 'sha256' is recommended.",
    :default => "sha256" do |value|
    if !DIGEST_ALGORITHMS.include?(value.downcase)
      raise "Unknown digest algorithm '#{value}'. Valid options " \
        "include: #{DIGEST_ALGORITHM_MAP.keys.join(", ")}"
    end
    value.downcase
  end

  option "--changelog", "FILEPATH", "Add changelog from FILEPATH contents" do |file|
    File.read(File.expand_path(file))
  end

  option "--sign", :flag, "Pass --sign to makepkg"

  option "--check-script", "FILE",
    "A script to be sourced when running the check() verification" do |val|
    File.expand_path(val) # Get the full path to the script
  end # --check-script



  # This method is invoked on a package when it has been convertxed to a new
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
    safesystem("tar", "-C", staging_path, "-xf", pacman_pkg_path)
    pkginfo = File.join(staging_path, ".PKGINFO")
    mtree = File.join(staging_path, ".MTREE")
    install = File.join(staging_path, ".INSTALL")

    control_contents = File.read(pkginfo)
    FileUtils.rm(pkginfo)
    FileUtils.rm(mtree)
    FileUtils.rm(install)


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
    self.category = control["group"][0] || self.category

    # Licenses could include more than one.
    # Speaking of just taking the first entry of the field:
    # A crude thing to do, but I suppose it's better than nothing.
    # -- Daniel Haskin, 3/24/2015
    self.license = control["license"][0] || self.license

    self.architecture = ["arch"][0]

    self.dependencies = control["depend"] || self.dependencies

    self.provides = control["provides"] || self.provides

    self.conflicts = control["conflict"] || self.conflict

    self.replaces = control["replaces"] || self.replaces

    self.description = control["pkgdesc"][0]

    self.config_files = control["backup"].map{|file| "/" + file}

    self.dependencies = control["depend"] || self.dependencies

    self.attributes["size"] = control["size"][0]
    self.attributes["builddate"] = control["builddate"][0]
    self.attributes["optdepend"] = control["optdepend"] || nil
    # There are other available attributes, but I didn't include them because:
    # - makedepend: deps needed to make the arch package. But it's already
    #   made. It just needs to be converted at this point
    # - checkdepend: See above
    # - makepkgopt: See above

    # TODO: scripts, directories.
    # For directories, see line 436 of rpm's output() to see what directories
    #   are all about.
    # TODO: install script
    # This is difficult. We have to extract the contents of
    # bash functions.
    #install_parts = { "global": [] }
    #install_contents = File.read(install).split("\n")
    #install_contents.each do |install_line|
    #  m = /^\s*(\w+)\s*\(\s*\)\s*{\s*$/.match(install_line)
    #  if m.nil?
    #    install_parts["global"].push(install_line)
    #  else
    #    install_parts[m[1]]
    #  end
    #end
    #parse_install = lambda do |field|
    #pre_install — The script is run right before files are
    #extracted. One argument is passed: new package version.
    #post_install — The script is run right after files are
    #extracted. One argument is passed: new package version.
    #pre_upgrade — The script is run right before files are
    #extracted. Two arguments are passed in the following order: new
    #package version, old package version.  post_upgrade — The script
    #is run right after files are extracted. Two arguments are passed
    #in the following order: new package version, old package version.
    #pre_remove — The script is run right before files are
    #removed. One argument is passed: old package version.
    #post_remove — The script is run right after files are
    #removed. One argument is passed: old package version.

    
  end # def input

  private
  # Output this package to the given path.
  def output(path)
    output_check(path)
    # write .PKGINFO (generate) to staging_path
    # write .INSTALL (template) to staging_path
    # write .MTREE (See below command) to staging_path
    #   command to generate .MTREE
    #     LANG=C bsdtar -czf .MTREE --format=mtree \
    #     --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' \
    #     .INSTALL .PKGINFO *
    # Tar up
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "creating #{self.type} packages")
  end # def output

end # class FPM::Package::Pacman
