require "fpm/package"
require "backports"
require "fileutils"
require "find"


class FPM::Package::Pacman < FPM::Package

  DIGEST_ALGORITHM_SET = {
    "md5",
    "sha1",
    "sha224",
    "sha256",
    "sha384",
    "sha512"
  } unless defined?(DIGEST_ALGORITHM_SET)

  option "--user", "USER", "Set the user to USER in the %files section. Overrides the user when used with use-file-permissions setting."

  option "--group", "GROUP", "Set the group to GROUP in the %files section. Overrides the group when used with use-file-permissions setting."

  option "--digest", DIGEST_ALGORITHM_SET.join("|"),
    "Select a digest algorithm. The algorithm 'sha256' is recommended.",
    :default => "sha256" do |value|
    if !DIGEST_ALGORITHM_MAP.include?(value.downcase)
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
  def input(thing_to_input)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "reading #{self.type} packages")
  end # def input

  # Output this package to the given path.
  def output(path)
    raise NotImplementedError.new("#{self.class.name} does not yet support " \
                                  "creating #{self.type} packages")
  end # def output

end # class FPM::Package::Pacman
