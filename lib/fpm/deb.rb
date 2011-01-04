#!/usr/bin/env ruby
#

require "erb"
require "fpm/namespace"
require "fpm/package"

class FPM::Deb < FPM::Package

  # Assemble the package.
  # params:
  #  "root" => "/some/path"   # the 'root' of your package directory
  #  "paths" => [ "/some/path" ...]  # paths to icnlude in this package
  #  "output" => "foo.deb"  # what to output to.
  #
  # The 'output' file path will have 'VERSION' and 'ARCH' replaced with
  # the appropriate values if if you want the filename generated.
  def assemble(params)
    raise "No package name given. Can't assemble package" if !@name

    root = params["root"]
    paths = params["paths"]
    output = params["output"]
    type = "deb" 

    # Debian calls x86_64 "amd64"
    @architecture = "amd64" if @architecture == "x86_64"

    output.gsub!(/VERSION/, "#{@version}-#{@iteration}")
    output.gsub!(/ARCH/, @architecture)

    builddir = "#{Dir.pwd}/build-#{type}-#{File.basename(output)}"
    @garbage << builddir

    Dir.mkdir(builddir) if !File.directory?(builddir)

    Dir.chdir(root || ".") do 
      self.tar("#{builddir}/data.tar", paths)
      # TODO(sissel): Make a helper method.
      system(*["gzip", "-f", "#{builddir}/data.tar"])

      # Generate md5sums
      md5sums = self.checksum(paths)
      File.open("#{builddir}/md5sums", "w") { |f| f.puts md5sums.join("\n") }

      # Generate 'control' file
      template = File.new("#{File.dirname(__FILE__)}/../../templates/deb.erb").read()
      control = ERB.new(template, nil, "<>").result(binding)
      File.open("#{builddir}/control", "w") { |f| f.puts control }
    end

    # create control.tar.gz
    Dir.chdir(builddir) do
      # Make the control
      system("tar -zcf control.tar.gz control md5sums")
     
      # create debian-binary
      File.open("debian-binary", "w") { |f| f.puts "2.0" }

      # pack up the .deb
      File.delete(output) if File.exists?(output)
      system("ar -qc #{output} debian-binary control.tar.gz data.tar.gz")
    end
  end  # def assemble

  def checksum(paths)
    md5sums = []
    paths.each do |path|
      md5sums += %x{find #{path} -type f -print0 | xargs -0 md5sum}.split("\n")
    end
  end # def checksum
end # class FPM::Deb

