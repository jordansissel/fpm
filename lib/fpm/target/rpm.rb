class FPM::Rpm < FPM::Package
  def assemble(params)
    # TODO [Jay] a lot of this is duplication from deb.rb,
    # and can be factored out.

    raise "No package name given. Can't assemble package" if !@name

    root = params['root'] || '.'
    paths = params['paths']
    output = params['output']

    type = "rpm"

    output.gsub!(/VERSION/, "#{@version}-#{@iteration}")
    output.gsub!(/ARCH/, @architecture)

    builddir = "#{Dir.pwd}/build-#{type}-#{File.basename(output)}"

    Dir.mkdir(builddir) if !File.directory?(builddir)

    Dir.chdir root do
      tar("#{builddir}/data.tar", paths)
      system(*["gzip", "-f", "#{builddir}/data.tar"])
    end
  end
end
