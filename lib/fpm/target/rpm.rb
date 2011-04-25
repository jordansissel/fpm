require "fpm/package"

class FPM::Target::Rpm < FPM::Package
  def specfile(builddir)
    "#{builddir}/#{name}.spec"
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
    ret = system(*args)
    if !ret
      raise "rpmbuild failed (exit code: #{$?.exitstatus})"
    end

    Dir["#{Dir.pwd}/RPMS/**/*.rpm"].each do |path|
      # This should only output one rpm, should we verify this?
      system("mv", path, params[:output])
    end

  end
end
