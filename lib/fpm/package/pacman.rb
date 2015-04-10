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

  private

  # This method is invoked on a package when it has been convertxed to a new
  # package format. The purpose of this method is to do any extra conversion
  # steps, like translating dependency conditions, etc.
  #def converted_from(origin)
    # nothing to do by default. Subclasses may implement this.
    # See the RPM package class for an example.
  #end # def converted_from

  def parse_info(info)
    info_map = {}
    last_match_key = nil
    info.each_line do |line|
      match = /^([[:alpha:]]+(?: [[:alpha:]]+)*) +: +(.*)$/.match(line)
      if not match.nil? and match[2] !~ /^[[:space:]]*[Nn]one[[:space:]]*$/
        info_map[match[1]] = match[2]
        last_match_key = match[1]
      else
        info_map[last_match_key] = info_map[last_match_key] + " " + line.chomp()
      end
    end
    return info_map
  end

  def extract_info(pacman_pkg_path)
    info = safesystemout("/usr/bin/pacman", "-Qpi", pacman_pkg_path)
    fields = parse_info(info)

    self.name = fields["Name"]

    # Parse 'epoch:version-iteration' in the version string
    version_re = /^(?:([0-9]+):)?(.+?)(?:-(.*))?$/
    m = version_re.match(fields["Version"])
    if !m
      raise "Unsupported version string '#{fields["Version"]}'"
    end

    self.epoch, self.version, self.iteration = m.captures

    if fields.has_key?("Packager")
      self.maintainer = fields["Packager"]
    end

    # `vendor' tag simply isn't supported by arch
    self.vendor = nil

    if fields.has_key?("URL")
      self.url = fields["URL"]
    end

    # Groups could include more than one.
    # Speaking of just taking the first entry of the field:
    # A crude thing to do, but I suppose it's better than nothing.
    # -- Daniel Haskin, 3/24/2015
    if fields.has_key?("Groups")
      groups = fields["Groups"].split()
      if groups.length > 0
        self.category = groups[0]
      end
    end

    # Licenses could include more than one.
    # Speaking of just taking the first entry of the field:
    # A crude thing to do, but I suppose it's better than nothing.
    # -- Daniel Haskin, 3/24/2015
    if fields.has_key?("Licenses")
      licenses = fields["Licenses"].split()
      if licenses.length > 0
        self.license = licenses[0]
      end
    end

    self.architecture = fields["Architecture"]

    if fields.has_key?("Depends On")
      self.dependencies = fields["Depends On"].split()
    end

    if fields.has_key?("Provides")
      provides = fields["Provides"]
      self.provides = fields["Provides"].split()
    end

    # TODO: scripts, config_files, directories, attributes (optional for).

    if fields.has_key?("Conflicts With")
      conflicts = fields["Conflicts With"].split()
      if conflics != "None"
        self.conflicts = conflicts
      end
    end

    if fields.has_key?("Replaces")
      replaces = fields["Replaces"].split()
      if replaces != "None"
        self.replaces = replaces
      end
    end

    if fields.has_key?("Description")
      self.description = fields["Description"]
    end
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
    extract_info(pacman_pkg_path)
    extract_files(pacman_pkg_path)
#Optional Deps  : bash-completion: for tab completion
#Conflicts With : None
#Replaces       : None
#Installed Size :   6.18 MiB
#Packager       : Bart
#Build Date     : Tue Dec 30 22:08:56 2014
#Install Date   : Sat Mar 14 04:28:54 2015
#Install Reason : Explicitly installed
#Install Script : Yes
#Validated By   : Signature

  end # def input

  # Output this package to the given path.
  def output(path)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "creating #{self.type} packages")
  end # def output

end # class FPM::Package::Pacman
