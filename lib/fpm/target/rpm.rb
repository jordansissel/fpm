require "fpm/package"

class FPM::Target::Rpm < FPM::Package
  def specfile(builddir)
    "#{builddir}/#{name}.spec"
  end

  def build!(params)
    raise "No package name given. Can't assemble package" if !@name
    Dir.mkdir("BUILD")
    args = ["rpmbuild", "-ba", 
           "--define", "buildroot #{Dir.pwd}/BUILD",
           "--define", "_topdir #{Dir.pwd}",
           "--define", "_sourcedir #{Dir.pwd}",
           "--define", "_rpmdir #{params[:output]}",
           "#{name}.spec"]
    system(*args)
  end
end
