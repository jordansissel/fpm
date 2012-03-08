require "fpm/package"
require "backports"
require "fileutils"
require "find"
require "arr-pm/file" # gem 'arr-pm'

# RPM Package type.
#
# Build RPMs without having to waste hours reading Maximum-RPM.
# Well, in case you want to read it, here: http://www.rpm.org/max-rpm/
#
# The following attributes are supported:
#
# * :rpm_rpmbuild_define - an array of definitions to give to rpmbuild.
#   These are used, verbatim, each as: --define ITEM
class FPM::Package::RPM < FPM::Package
  option "--rpmbuild-define", "DEFINITION",
    "Pass a --define argument to rpmbuild." do |define|
    attributes[:rpm_rpmbuild_define] ||= []
    attributes[:rpm_rpmbuild_define] << define
  end

  private

  def architecture
    case @architecture
      when nil
        return %x{uname -m}.chomp   # default to current arch
      when "native"
        return %x{uname -m}.chomp   # 'native' is current arch
      when "all"
        # Translate fpm "all" arch to what it means in RPM.
        return "noarch"
      else
        return @architecture
    end
  end # def architecture

  # See FPM::Package#converted_from
  def converted_from(origin)
    if origin == FPM::Package::Gem
      # Gem dependency operator "~>" is not compatible with rpm. Translate any found.
      fixed_deps = []
      self.dependencies.collect do |dep|
        name, op, version = dep.split(/\s+/)
        if op == "~>"
          # ~> x.y means: > x.y and < (x+1).0
          fixed_deps << "#{name} > #{version}"
          fixed_deps << "#{name} < #{version.to_i + 1}.0.0"
        else
          fixed_deps << dep
        end
      end
      self.dependencies = fixed_deps
    end
  end # def converted

  def input(path)
    rpm = ::RPM::File.new(path)

    tags = {}
    rpm.header.tags.each do |tag|
      tags[tag.tag] = tag.value
    end

    self.architecture = tags[:arch]
    self.category = tags[:group]
    self.config_files = config_files
    self.description = tags[:description]
    self.epoch = tags[:epoch].first # for some reason epoch is an array
    self.iteration = tags[:release]
    self.license = tags[:license]
    self.maintainer = maintainer
    self.name = tags[:name]
    self.url = tags[:url]
    self.vendor = tags[:vendor]
    self.version = tags[:version]

    # TODO(sissel): Collect {pre,post}{install,uninstall} scripts
    # TODO(sissel): put 'trigger scripts' stuff into attributes
    # TODO(sissel): support provides
    # TODO(sissel): support conflicts
    # TODO(sissel): support replaces

    self.dependencies += rpm.requires.collect do |name, operator, version|
      [name, operator, version].join(" ")
    end
    #input.replaces += replaces

    # Extract to the staging directory
    rpm.extract(staging_path)
  end # def input

  def output(output_path)
    %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| FileUtils.mkdir_p(File.join(build_path, d)) }
    args = ["rpmbuild", "-bb",
      "--define", "buildroot #{build_path}/BUILD",
      "--define", "_topdir #{build_path}",
      "--define", "_sourcedir #{build_path}",
      "--define", "_rpmdir #{build_path}/RPMS"]

    (attributes[:rpm_rpmbuild_define] or []).each do |define|
      args += ["--define", define]
    end

    rpmspec = template("rpm.erb").result(binding)
    specfile = File.join(build_path, "SPECS", "#{name}.spec")
    File.write(specfile, rpmspec)
    File.write("/tmp/rpm.spec", rpmspec)

    args << specfile
    #if defines.empty?
      #args = prefixargs + spec
    #else
      #args = prefixargs + defines.collect{ |define| ["--define", define] }.flatten + spec
    #end

    @logger.info("Running rpmbuild", :args => args)
    safesystem(*args)

    ::Dir["#{build_path}/RPMS/**/*.rpm"].each do |rpmpath|
      # This should only output one rpm, should we verify this?
      FileUtils.cp(rpmpath, output_path)
    end

    @logger.log("Created rpm", :path => output_path)
  end # def output

  public(:input, :output, :converted_from)
end # class FPM::Package::RPM
