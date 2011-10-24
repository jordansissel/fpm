require "fpm/package"
require "fpm/util"

class FPM::Target::Rpm < FPM::Package
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

  def url
    if @url.nil? || @url.empty?
      'http://nourlgiven.example.com'
    else
      @url
    end
  end

  def iteration
    if @iteration.nil? || @iteration.empty?
      '1'
    else
      @iteration
    end
  end

  def version
    if @version.kind_of?(String) and @version.include?("-")
      @logger.info("Package version '#{@version}' includes dashes, converting" \
                   " to underscores")
      @version = @version.gsub(/-/, "_")
    end

    return @version
  end

  def build!(params)
    raise "No package name given. Can't assemble package" if !@name
    # TODO(sissel): Abort if 'rpmbuild' tool not found.

    %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| Dir.mkdir(d) }
    args = ["rpmbuild", "-ba",
           "--define", "buildroot #{Dir.pwd}/BUILD",
           "--define", "_topdir #{Dir.pwd}",
           "--define", "_sourcedir #{Dir.pwd}",
           "--define", "_rpmdir #{Dir.pwd}/RPMS",
           "#{name}.spec"]
    safesystem(*args)

    Dir["#{Dir.pwd}/RPMS/**/*.rpm"].each do |path|
      # This should only output one rpm, should we verify this?
      safesystem("mv", path, params[:output])
    end
  end # def build!
end # class FPM::Target::RPM
