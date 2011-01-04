#!/usr/bin/env ruby
#

require "erb"
require "fpm/namespace"
require "fpm/package"

class FPM::Deb < FPM::Package
  # Debian calls x86_64 "amd64"
  def architecture
    if @architecture == "x86_64"
      "amd64"
    else
      @architecture
    end
  end

  def specfile(builddir)
    "#{builddir}/control"
  end

  def build(params)
    # Make the control
    system("tar -zcf control.tar.gz control md5sums")

    # create debian-binary
    File.open("debian-binary", "w") { |f| f.puts "2.0" }

    # pack up the .deb
    File.delete(output) if File.exists?(output)
    system("ar -qc #{params["output"]} debian-binary control.tar.gz data.tar.gz")

  end # def build
end # class FPM::Deb

