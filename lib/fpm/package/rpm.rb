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
  DIGEST_ALGORITHM_MAP = {
    "md5" => 1,
    "sha1" => 2,
    "sha256" => 8,
    "sha384" => 9,
    "sha512" => 10
  } unless defined?(DIGEST_ALGORITHM_MAP)

  COMPRESSION_MAP = {
    "xz" => "w2.xzdio",
    "gzip" => "w9.gzdio",
    "bzip2" => "w9.bzdio"
  } unless defined?(COMPRESSION_MAP)

  option "--user", "USER",
    "Set the user to USER in the %files section.", 
    :default => 'root' do |value|
      value
  end

  option "--group", "GROUP",
    "Set the group to GROUP in the %files section.",
    :default => 'root' do |value|
      value
  end

  option "--rpmbuild-define", "DEFINITION",
    "Pass a --define argument to rpmbuild." do |define|
    attributes[:rpm_rpmbuild_define] ||= []
    attributes[:rpm_rpmbuild_define] << define
  end

  option "--digest", DIGEST_ALGORITHM_MAP.keys.join("|"),
    "Select a digest algorithm. md5 works on the most platforms.",
    :default => "md5" do |value|
    if !DIGEST_ALGORITHM_MAP.include?(value.downcase)
      raise "Unknown digest algorithm '#{value}'. Valid options " \
        "include: #{DIGEST_ALGORITHM_MAP.keys.join(", ")}"
    end
    value.downcase
  end

  option "--compression", COMPRESSION_MAP.keys.join("|"),
    "Select a compression method. gzip works on the most platforms.",
    :default => "gzip" do |value|
    if !COMPRESSION_MAP.include?(value.downcase)
      raise "Unknown compression type '#{value}'. Valid options " \
        "include: #{COMPRESSION_MAP.keys.join(", ")}"
    end
    value.downcase
  end

  private

  # Handle any architecture naming conversions.
  # For example, debian calls amd64 what redhat calls x86_64, this
  # method fixes those types of things.
  def architecture
    case @architecture
      when nil
        return %x{uname -m}.chomp   # default to current arch
      when "amd64" # debian and redhat disagree on architecture names
        return "x86_64"
      when "native"
        return %x{uname -m}.chomp   # 'native' is current arch
      when "all"
        # Translate fpm "all" arch to what it means in RPM.
        return "noarch"
      else
        return @architecture
    end
  end # def architecture

  # This method ensures a default value for iteration if none is provided.
  def iteration
    return @iteration ? @iteration : 1
  end # def iteration

  # See FPM::Package#converted_from
  def converted_from(origin)
    if origin == FPM::Package::Gem
      # Gem dependency operator "~>" is not compatible with rpm. Translate any found.
      fixed_deps = []
      self.dependencies.collect do |dep|
        name, op, version = dep.split(/\s+/)
        if op == "~>"
          # ~> x.y means: > x.y and < (x+1).0
          fixed_deps << "#{name} >= #{version}"
          fixed_deps << "#{name} < #{version.to_i + 1}.0.0"
        else
          fixed_deps << dep
        end
      end
      self.dependencies = fixed_deps

      # Convert 'rubygem-foo' provides values to 'rubygem(foo)'
      # since that's what most rpm packagers seem to do.
      self.provides = self.provides.collect do |provides|
        first, remainder = provides.split("-", 2)
        if first == "rubygem"
          name, remainder = remainder.split(" ", 2)
          # yield rubygem(name)...
          "rubygem(#{name})#{remainder ? " #{remainder}" : ""}"
        else
          provides
        end
      end
      self.dependencies = self.dependencies.collect do |dependency|
        first, remainder = dependency.split("-", 2)
        if first == "rubygem"
          name, remainder = remainder.split(" ", 2)
          "rubygem(#{name})#{remainder ? " #{remainder}" : ""}"
        else
          dependency
        end
      end
      #self.provides << "rubygem(#{self.name})"
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
    self.description = tags[:description]
    self.epoch = (tags[:epoch] || [nil]).first # for some reason epoch is an array
    self.iteration = tags[:release]
    self.license = tags[:license]
    self.maintainer = maintainer
    self.name = tags[:name]
    self.url = tags[:url]
    self.vendor = tags[:vendor]
    self.version = tags[:version]

    self.scripts[:before_install] = tags[:prein]
    self.scripts[:after_install] = tags[:postin]
    self.scripts[:before_remove] = tags[:preun]
    self.scripts[:after_remove] = tags[:postun]
    # TODO(sissel): prefix these scripts above with a shebang line if there isn't one?
    # Also taking into account the value of tags[preinprog] etc, something like:
    #    #!#{tags[:preinprog]}
    #    #{tags[prein]}
    # TODO(sissel): put 'trigger scripts' stuff into attributes

    self.dependencies += rpm.requires.collect do |name, operator, version|
      [name, operator, version].join(" ")
    end
    self.conflicts += rpm.conflicts.collect do |name, operator, version|
      [name, operator, version].join(" ")
    end
    self.provides += rpm.provides.collect do |name, operator, version|
      [name, operator, version].join(" ")
    end
    #input.replaces += replaces
    
    self.config_files += rpm.config_files
    self.directories += rpm.directories

    # Extract to the staging directory
    rpm.extract(staging_path)
  end # def input

  def output(output_path)
    output_check(output_path)
    raise FileAlreadyExists.new(output_path) if File.exists?(output_path)
    %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| FileUtils.mkdir_p(build_path(d)) }
    args = ["rpmbuild", "-bb",
      "--define", "buildroot #{build_path}/BUILD",
      "--define", "_topdir #{build_path}",
      "--define", "_sourcedir #{build_path}",
      "--define", "_rpmdir #{build_path}/RPMS"]

    (attributes[:rpm_rpmbuild_define] or []).each do |define|
      args += ["--define", define]
    end

    rpmspec = template("rpm.erb").result(binding)
    specfile = File.join(build_path("SPECS"), "#{name}.spec")
    File.write(specfile, rpmspec)

    edit_file(specfile) if attributes[:edit?]

    args << specfile

    @logger.info("Running rpmbuild", :args => args)
    safesystem(*args)

    ::Dir["#{build_path}/RPMS/**/*.rpm"].each do |rpmpath|
      # This should only output one rpm, should we verify this?
      FileUtils.cp(rpmpath, output_path)
    end

    @logger.log("Created rpm", :path => output_path)
  end # def output

  def prefix
    return (attributes[:prefix] or "/")
  end # def prefix

  def build_sub_dir
    return "BUILD"
    #return File.join("BUILD", prefix)
  end # def prefix

  # The default epoch value must be 1 (backward compatibility for rpms built
  # with fpm 0.4.3 and older)
  def epoch
    return @epoch || "1"
  end # def epoch

  def to_s(format=nil)
    return super("NAME-VERSION-ITERATION.ARCH.TYPE") if format.nil?
    return super(format)
  end # def to_s

  def payload_compression
    return COMPRESSION_MAP[attributes[:rpm_compression]]
  end # def payload_compression

  def digest_algorithm
    return DIGEST_ALGORITHM_MAP[attributes[:rpm_digest]]
  end # def digest_algorithm

  public(:input, :output, :converted_from, :architecture, :to_s, :iteration,
         :payload_compression, :digest_algorithm, :prefix, :build_sub_dir,
         :epoch)
end # class FPM::Package::RPM
