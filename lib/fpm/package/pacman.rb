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
        prod.push(line)
      else
        fine = line.sub(/\s*[}]\s*$/, "")
        if !(fine =~ /^\s*$/)
          prod.push(fine)
        end
      end
    end
  end

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
          m = /^\s*(\w+)\s*\(\s*\)\s*\{\s*([^}]+?)?\s*(\})?\s*$/.match(
            line)
          if not m.nil? and look_for.include? m[1]
            if not m[2].nil?
              functions[m[1]].push(m[2])
            end
            gobble_function(lines, functions[m[1]])
          else
            global_lines.push(line)
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
  end


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

    self.attributes["optdepend"] = control["optdepend"] || nil
    # There are other available attributes, but I didn't include them because:
    # - makedepend: deps needed to make the arch package. But it's already
    #   made. It just needs to be converted at this point
    # - checkdepend: See above
    # - makepkgopt: See above
    # - size: can be dynamically generated
    # - builddate: Should be changed to time of package conversion in the new
    #   package, so this value should be thrown away.

    functions = parse_install_script(install)
    if functions.include?("pre_install")
      self.scripts[:before_install] = functions["pre_install"]
    end
    if functions.include?("post_install")
      self.scripts[:after_install] = functions["post_install"]
    end
    if functions.include?("pre_upgrade")
      self.scripts[:before_ugrade] = functions["pre_upgrade"]
    end
    if functions.include?("post_upgrade")
      self.scripts[:after_upgrade] = functions["post_upgrade"]
    end
    if functions.include?("pre_remove")
      self.scripts[:before_remove] = functions["pre_remove"]
    end
    if functions.include?("post_remove")
      self.scripts[:after_remove] = functions["post_remove"]
    end
    FileUtils.rm(install)

    # Note: didn't use `self.directories`.
    # Pacman doesn't really record that information, to my knowledge.

  end # def input


  # Output this package to the given path.
  def output(path)
    #output_check(path)
    #generate_pkginfo()
    #open('.PKGINFO', 'w') do |pkginfo|
    #  pkginfo.puts "# Generated by fpm"
    #  pkginfo.puts "pkgname = " + self.name
    #end
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

  private

end # class FPM::Package::Pacman
