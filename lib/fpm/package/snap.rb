require "yaml"

require "fpm/package"
require "fpm/util"
require "fileutils"
require "fpm/package/dir"

# Support for snaps (.snap files).
#
# This supports the input and output of snaps.
class FPM::Package::Snap < FPM::Package

  option "--yaml", "FILEPATH",
    "Custom version of the snap.yaml file." do | snap_yaml |
    File.expand_path(snap_yaml)
  end

  option "--confinement", "CONFINEMENT",
    "Type of confinement to use for this snap.",
    default: "devmode" do | confinement |
    if ['strict', 'devmode', 'classic'].include? confinement
      confinement
    else
      raise "Unsupported confinement type '#{confinement}'"
    end
  end

  option "--grade", "GRADE", "Grade of this snap.",
    default: "devel" do | grade |
    if ['stable', 'devel'].include? grade
      grade
    else
      raise "Unsupported grade type '#{grade}'"
    end
  end

   # Input a snap
  def input(input_snap)
    extract_snap_to_staging input_snap
    extract_snap_metadata_from_staging
  end # def input

  # Output a snap.
  def output(output_snap)
    output_check(output_snap)

    write_snap_yaml

    # Create the snap from the staging path
    safesystem("mksquashfs", staging_path, output_snap, "-noappend", "-comp",
               "xz", "-no-xattrs", "-no-fragments", "-all-root")
  end # def output

  def to_s(format=nil)
    # Default format if nil
    # name_version_arch.snap
    return super(format.nil? ? "NAME_FULLVERSION_ARCH.EXTENSION" : format)
  end # def to_s

  private

  def extract_snap_to_staging(snap_path)
    safesystem("unsquashfs", "-f", "-d", staging_path, snap_path)
  end

  def extract_snap_metadata_from_staging
    metadata = YAML.safe_load(File.read(
      staging_path(File.join("meta", "snap.yaml"))))

    self.name = metadata["name"]
    self.version = metadata["version"]
    self.description = metadata["summary"] + "\n" + metadata["description"]
    self.architecture = metadata["architectures"][0]
    self.attributes[:snap_confinement] = metadata["confinement"]
    self.attributes[:snap_grade] = metadata["grade"]

    if metadata["apps"].nil?
      attributes[:snap_apps] = []
    else
      attributes[:snap_apps] = metadata["apps"]
    end

    if metadata["hooks"].nil?
      attributes[:snap_hooks] = []
    else
      attributes[:snap_hooks] = metadata["hooks"]
    end
  end

  def write_snap_yaml
    # Write the snap.yaml
    if attributes[:snap_yaml]
      logger.debug("Using '#{attributes[:snap_yaml]}' as the snap.yaml")
      yaml_data = File.read(attributes[:snap_yaml])
    else
      summary, *remainder = (self.description or "no summary given").split("\n")
      description = "no description given"
      if remainder.any?
        description = remainder.join("\n")
      end

      yaml_data = {
        "name" => self.name,
        "version" => self.version,
        "summary" => summary,
        "description" => description,
        "architectures" => [self.architecture],
        "confinement" => self.attributes[:snap_confinement],
        "grade" => self.attributes[:snap_grade],
      }

      unless attributes[:snap_apps].nil? or attributes[:snap_apps].empty?
        yaml_data["apps"] = attributes[:snap_apps]
      end

      unless attributes[:snap_hooks].nil? or attributes[:snap_hooks].empty?
        yaml_data["hooks"] = attributes[:snap_hooks]
      end

      yaml_data = yaml_data.to_yaml
    end

    FileUtils.mkdir_p(staging_path("meta"))
    snap_yaml_path = staging_path(File.join("meta", "snap.yaml"))
    logger.debug("Writing snap.yaml", :path => snap_yaml_path)
    File.write(snap_yaml_path, yaml_data)
    File.chmod(0644, snap_yaml_path)
    edit_file(snap_yaml_path) if attributes[:edit?]
  end # def write_snap_yaml
end # class FPM::Package::Snap
