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
      if not match.nil?
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
    # Parse 'epoch:version-iteration' in the version string
    version_re = /^(?:([0-9]+):)?(.+?)(?:-(.*))?$/
    m = version_re.match(parse.call("Version"))
    if !m
      raise "Unsupported version string '#{parse.call("Version")}'"
    end
    self.epoch, self.version, self.iteration = m.captures
    self.architecture = fields["Architecture"]
    self.category = nil
    # TODO: Licenses could include more than one.
    # How to handle this?
    self.license = fields["Licenses"] || self.license
    self.maintainer = fields["Packager"]
    self.name = fields["Name"]
    self.url = fields["URL"]
    # `vendor' tag makes no sense. It's ARCH
    # TODO: What if the `provides` field doesn't exist?
    self.provides = fields["Provides"].split()
    self.description = fields["Description"]
    self.dependencies = fields["Dependencies"].split()
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
    
#    Name           : bash
#Version        : 4.3.033-1
#Description    : The GNU Bourne Again shell
#Architecture   : x86_64
#URL            : http://www.gnu.org/software/bash/bash.html
#Licenses       : GPL
#Groups         : base
#Provides       : sh
#Depends On     : readline>=6.3  glibc
#Optional Deps  : bash-completion: for tab completion
#Required By    : autoconf  automake  bison  ca-certificates-utils  db  dhcpcd  diffutils  e2fsprogs
#                 fakeroot  findutils  flex  freetype2  gawk  gdbm  gettext  gmp  gzip  iptables  keyutils
#                 libgpg-error  libksba  libpng  libtool  lvm2  m4  make  man-db  mkinitcpio  nano
#                 ncurses  openresolv  pacman  pcre  sed  shadow  systemd  texinfo  which  xorg-mkfontdir
#                 xz
#Optional For   : None
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
