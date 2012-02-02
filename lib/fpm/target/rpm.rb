require "fpm/package"
require "fpm/util"

class FPM::Target::Rpm < FPM::Package
  def self.flags(opts, settings)
    settings.target[:rpm] = "rpm"

    opts.on("--rpmbuild-define DEFINITION", "Pass a --define argument to rpmbuild.") do |define|
      (settings.target[:rpmbuild_define] ||= []) << define
    end
  end

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

  def specfile(builddir)
    "#{builddir}/#{name}.spec"
  end

  # Override inherited method so we can properly substitute in configuration
  # files which require special directives in the spec file.
  def render_spec
    # find all files in paths given.
    paths = []
    @source.paths.each do |path|
      Find.find(path) { |p| paths << p }
    end

    # Ensure all paths are absolute and don't start with '.'
    paths.collect! { |p| p.gsub(/^\.\//, "/").gsub(/^[^\/]/, "/\\0") }
    @config_files.collect! { |c| c.gsub(/^\.\//, "/").gsub(/^[^\/]/, "/\\0") }

    # Remove config files from the main path list, as files cannot be listed
    # twice (rpmbuild complains).
    paths -= @config_files

    #@logger.info(:paths => paths.sort)
    template.result(binding)
  end # def render_spec

  def url
    if @url.nil? || @url.empty?
      'http://nourlgiven.example.com'
    else
      @url
    end
  end

  def iteration
    if @iteration.nil? || @iteration.empty?
      # Default iteration value of 1 makes sense.
      return '1'
    else
      return @iteration
    end
  end # def iteration

  def version
    if @version.kind_of?(String) and @version.include?("-")
      @logger.info("Package version '#{@version}' includes dashes, converting" \
                   " to underscores")
      @version = @version.gsub(/-/, "_")
    end

    return @version
  end

  def defines
    self.settings[:rpmbuild_define] || []
  end

  def build!(params)
    raise "No package name given. Can't assemble package" if !@name
    # TODO(sissel): Abort if 'rpmbuild' tool not found.

    %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| Dir.mkdir(d) }
    prefixargs = ["rpmbuild", "-ba",
      "--define", "buildroot #{Dir.pwd}/BUILD",
      "--define", "_topdir #{Dir.pwd}",
      "--define", "_sourcedir #{Dir.pwd}",
      "--define", "_rpmdir #{Dir.pwd}/RPMS"]

    spec = ["#{name}.spec"]

    if defines.empty?
      args = prefixargs + spec
    else
      args = prefixargs + defines.collect{ |define| ["--define", define] }.flatten + spec
    end

    safesystem(*args)

    Dir["#{Dir.pwd}/RPMS/**/*.rpm"].each do |path|
      # This should only output one rpm, should we verify this?
      safesystem("mv", path, params[:output])
    end
  end # def build!
  
  def fix_dependency(dep)
     if dep =~ /[\(,\|]/
       # Don't "fix" ones that could appear well formed already.
     else
       da = dep.split(/ +/)
       if da.size > 1
         # Convert strings 'foo >= bar' to 'foo (>= bar)'
         dep = "#{da[0]} #{da[1]} #{da[2]}"
       end
     end

     # Convert gem ~> X.Y.Z to '>= X.Y.Z' and < X.Y+1.0
     if dep =~ /\~>/
       name, version = dep.gsub(/[()~>]/, "").split(/ +/)[0..1]
       nextversion = version.split(".").collect { |v| v.to_i }
       l = nextversion.length
       nextversion[l-2] += 1
       nextversion[l-1] = 0
       nextversion = nextversion.join(".")
       ["#{name} >= #{version}", "#{name} < #{nextversion}"]
     elsif dep =~ /\d [<>]=? [0-9.+] [<>]=? \d/
       # Convert gem >= A.B.C <= X.Y.Z to '>= A.B.C' and '<= X.Y.Z'
       puts dep
       # split out version numbers with their equality sign
       name, lower_version, upper_version = dep.scan(/([\w-]+) ([<>]=? [\d\.]+) ([<>]=? [\d\.]+)/)[0]
       ["#{name} #{lower_version}", "#{name} #{upper_version}"]
     elsif dep =~ /!=/
       name, version = dep.gsub(/!=/, "").split(/ +/)[0..1]
       ["#{name} > #{version}", "#{name} < #{version}"]      
     else
       dep
     end
   end # def fix_dependency
end # class FPM::Target::RPM
