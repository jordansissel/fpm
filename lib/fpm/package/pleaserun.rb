require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

require "pleaserun/cli"

# A pleaserun package.
#
# This does not currently support 'output'
class FPM::Package::PleaseRun < FPM::Package
  # TODO(sissel): Implement flags.
  
  require "pleaserun/platform/systemd"
  require "pleaserun/platform/upstart"
  require "pleaserun/platform/launchd"
  require "pleaserun/platform/sysv"

  option "--name", "SERVICE_NAME", "The name of the service you are creating"

  private
  def input(command)
    platforms = [
      ::PleaseRun::Platform::Systemd.new("default"),
      ::PleaseRun::Platform::Upstart.new("1.5"),
      ::PleaseRun::Platform::Launchd.new("10.9"),
      ::PleaseRun::Platform::SYSV.new("lsb-3.1")
    ]

    attributes[:pleaserun_name] ||= File.basename(command.first)
    attributes[:prefix] ||= "/usr/share/pleaserun/#{attributes[:pleaserun_name]}"

    platforms.each do |platform|
      logger.info("Generating service manifest.", :platform => platform.class.name)
      platform.program = command.first
      platform.name = attributes[:pleaserun_name]
      platform.args = command[1..-1]
      platform.description = attributes[:description]
      base = staging_path(File.join(attributes[:prefix], "#{platform.platform}-#{platform.target_version || "default"}"))
      target = File.join(base, "files")
      actions_script = File.join(base, "install_actions.sh")
      ::PleaseRun::Installer.install_files(platform, target, false)
      ::PleaseRun::Installer.write_actions(platform, actions_script)
    end

    scripts[:after_install] = template(File.join("pleaserun", "install.sh")).result(binding)
  end # def input

  public(:input)
end # class FPM::Package::PleaseRun
