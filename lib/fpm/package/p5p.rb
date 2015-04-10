require "erb"
require "fpm/namespace"
require "fpm/package"
require "fpm/errors"
require "fpm/util"

class FPM::Package::P5P < FPM::Package

  option "--user", "USER",
    "Set the user to USER in the prototype files.",
    :default => 'root'

  option "--group", "GROUP",
    "Set the group to GROUP in the prototype file.",
    :default => 'root'

  option "--zonetype", "ZONETYPE",
    "Set the allowed zone types (global, nonglobal, both)",
    :default => 'value=global value=nonglobal' do |value|
      case @value
      when "both"
        value = "value=global value=nonglobal"
      else
        value = "value=#{value}"
      end
    end # value

  option "--publisher", "PUBLISHER", 
    "Set the publisher name for the repository",
    :default => 'FPM'

  option "--lint" , :flag, "Check manifest with pkglint",
    :default => true

  option "--validate", :flag, "Validate with pkg install",
    :default => true

  def architecture
    case @architecture
    when nil, "native"
      @architecture = %x{uname -p}.chomp
    when "all"
      @architecture = 'i386 value=sparc'
    end

    return @architecture
  end # def architecture

  def output(output_path)
    
    # Fixup the category to an acceptable solaris category
    case @category
    when nil, "default"
      @category = 'Applications/System Utilities'
    end

    # Generate a package manifest.
    pkg_generate = safesystemout("pkgsend", "generate", "#{staging_path}")
    File.open("#{build_path}/#{name}.p5m.1", "w") do |manifest|
      manifest.puts pkg_generate
    end
    safesystem("cp", "#{build_path}/#{name}.p5m.1", "#{build_path}/#{name}.p5m")

    # Add necessary metadata to the generated manifest.
    metadata_template = template("p5p_metadata.erb").result(binding)
    File.open("#{build_path}/#{name}.mog", "w") do |manifest|
      manifest.puts metadata_template
    end
    pkg_mogrify = safesystemout("pkgmogrify", "#{build_path}/#{name}.p5m", "#{build_path}/#{name}.mog")
    File.open("#{build_path}/#{name}.p5m.2", "w") do |manifest|
      manifest.puts pkg_mogrify
    end
    safesystem("cp", "#{build_path}/#{name}.p5m.2", "#{build_path}/#{name}.p5m")

    # Evaluate dependencies.
    if !attributes[:no_auto_depends?]
	    pkgdepend_gen = safesystemout("pkgdepend", "generate",  "-md", "#{staging_path}",  "#{build_path}/#{name}.p5m")
	    File.open("#{build_path}/#{name}.p5m.3", "w") do |manifest|
	      manifest.puts pkgdepend_gen
	    end
	    safesystem("pkgdepend", "resolve",  "-m", "#{build_path}/#{name}.p5m.3")
	    safesystem("cp", "#{build_path}/#{name}.p5m.3.res", "#{build_path}/#{name}.p5m")
    end

    # Final format of manifest
    safesystem("pkgfmt", "#{build_path}/#{name}.p5m")

    edit_file("#{build_path}/#{name}.p5m") if attributes[:edit?]

    # Add any facets or actuators that are needed.
    # TODO(jcraig): add manpage actuator to enable install wo/ man pages

    # Verify the package.
    if attributes[:p5p_lint] then
      safesystem("pkglint", "#{build_path}/#{name}.p5m")
    end

    # Publish the package.
    safesystem("pkgrepo", "create", "#{build_path}/#{name}_repo")
    safesystem("pkgrepo", "set", "-s", "#{build_path}/#{name}_repo",
      "publisher/prefix=#{attributes[:p5p_publisher]}")
    safesystem("pkgsend", "-s", "#{build_path}/#{name}_repo",
      "publish", "-d", "#{staging_path}", "#{build_path}/#{name}.p5m")
    safesystem("pkgrecv", "-s", "#{build_path}/#{name}_repo", "-a",
      "-d", "#{build_path}/#{name}.p5p", "#{name}")

    # Test the package
    if attributes[:p5p_validate] then
      safesystem("pkg", "install",  "-nvg", "#{build_path}/#{name}.p5p", "#{name}")
    end

    # Cleanup
    safesystem("mv", "#{build_path}/#{name}.p5p", output_path)

  end # def output
end # class FPM::Package::IPS
