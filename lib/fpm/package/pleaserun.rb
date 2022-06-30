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
  option "--chdir", "CHDIR", "The working directory used by the service"
  option "--user", "USER", "The user to use for executing this program."
  option "--group", "GROUP", "The group to use for executing this program."
  option "--umask", "UMASK", "The umask to apply to this program"
  option "--chroot", "CHROOT", "The directory to chroot to"
  option "--nice", "NICE", "The nice level to add to this program before running"
  option "--limit-coredump", "LIMIT_COREDUMP", "Largest size (in blocks) of a core file that can be created. (setrlimit RLIMIT_CORE)"
  option "--limit-cputime", "LIMIT_CPUTIME", "Maximum amount of cpu time (in seconds) a program may use. (setrlimit RLIMIT_CPU)"
  option "--limit-data", "LIMIT_DATA", "Maximum data segment size (setrlimit RLIMIT_DATA)"
  option "--limit-file-size", "LIMIT_FILE_SIZE", "Maximum size (in blocks) of a file receiving writes (setrlimit RLIMIT_FSIZE)"
  option "--limit-locked-memory", "LIMIT_LOCKED_MEMORY", "Maximum amount of memory (in bytes) lockable with mlock(2) (setrlimit RLIMIT_MEMLOCK)"
  option "--limit-open-files", "LIMIT_OPEN_FILES", "Maximum number of open files, sockets, etc. (setrlimit RLIMIT_NOFILE)"
  option "--limit-user-processes", "LIMIT_USER_PROCESSES", "Maximum number of running processes (or threads!) for this user id. Not recommended because this setting applies to the user, not the process group. (setrlimit RLIMIT_NPROC)"
  option "--limit-physical-memory", "LIMIT_PHYSICAL_MEMORY", "Maximum resident set size (in bytes); the amount of physical memory used by a process. (setrlimit RLIMIT_RSS)"
  option "--limit-stack-size", "LIMIT_STACK_SIZE", "Maximum size (in bytes) of a stack segment (setrlimit RLIMIT_STACK)"
  option "--log-directory", "LOG_DIRECTORY", "The destination for log output"
  option "--log-file-stderr", "LOG_FILE_STDERR", "Name of log file for stderr. Will default to NAME-stderr.log"
  option "--log-file-stdout", "LOG_FILE_STDOUT", "Name of log file for stdout. Will default to NAME-stderr.log"




  private
  def input(command)
    platforms = [
      ::PleaseRun::Platform::Systemd.new("default"), # RHEL 7, Fedora 19+, Debian 8, Ubuntu 16.04
      ::PleaseRun::Platform::Upstart.new("1.5"), # Recent Ubuntus
      ::PleaseRun::Platform::Upstart.new("0.6.5"), # CentOS 6
      ::PleaseRun::Platform::Launchd.new("10.9"), # OS X
      ::PleaseRun::Platform::SYSV.new("lsb-3.1") # Ancient stuff
    ]
    pleaserun_attributes = [ "chdir", "user", "group", "umask", "chroot", "nice", "limit_coredump",
                             "limit_cputime", "limit_data", "limit_file_size", "limit_locked_memory",
                             "limit_open_files", "limit_user_processes", "limit_physical_memory", "limit_stack_size",
                             "log_directory", "log_file_stderr", "log_file_stdout"]

    attributes[:pleaserun_name] ||= File.basename(command.first)
    attributes[:prefix] ||= "/usr/share/pleaserun/#{attributes[:pleaserun_name]}"

    platforms.each do |platform|
      logger.info("Generating service manifest.", :platform => platform.class.name)
      platform.program = command.first
      platform.name = attributes[:pleaserun_name]
      platform.args = command[1..-1]
      platform.description = if attributes[:description_given?]
        attributes[:description]
      else
        platform.name
      end
      pleaserun_attributes.each do |attribute_name|
        attribute = "pleaserun_#{attribute_name}".to_sym
        if attributes.has_key?(attribute) and not attributes[attribute].nil?
          platform.send("#{attribute_name}=", attributes[attribute])
        end
      end

      base = staging_path(File.join(attributes[:prefix], "#{platform.platform}/#{platform.target_version || "default"}"))
      target = File.join(base, "files")
      actions_script = File.join(base, "install_actions.sh")
      ::PleaseRun::Installer.install_files(platform, target, false)
      ::PleaseRun::Installer.write_actions(platform, actions_script)
    end

    libs = [ "install.sh", "install-path.sh", "generate-cleanup.sh" ]
    libs.each do |file|
      base = staging_path(File.join(attributes[:prefix]))
      File.write(File.join(base, file), template(File.join("pleaserun", file)).result(binding))
      File.chmod(0755, File.join(base, file))
    end

    scripts[:after_install] = template(File.join("pleaserun", "scripts", "after-install.sh")).result(binding)
    scripts[:before_remove] = template(File.join("pleaserun", "scripts", "before-remove.sh")).result(binding)
  end # def input

  public(:input)
end # class FPM::Package::PleaseRun
