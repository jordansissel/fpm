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

    # Manifest Filename
    manifest_fn = build_path("#{name}.p5m")

    # Generate a package manifest.
    pkg_generate = safesystemout("pkgsend", "generate", "#{staging_path}")
    File.write(build_path("#{name}.p5m.1"), pkg_generate)

    # Add necessary metadata to the generated manifest.
    metadata_template = template("p5p_metadata.erb").result(binding)
    File.write(build_path("#{name}.mog"), metadata_template)

    # Combine template and filelist; allow user to edit before proceeding
    File.open(manifest_fn, "w") do |manifest|
      manifest.write metadata_template
      manifest.write pkg_generate
    end
    edit_file(manifest_fn) if attributes[:edit?]

    # Execute the transmogrification on the manifest
    pkg_mogrify = safesystemout("pkgmogrify", manifest_fn)
    File.write(build_path("#{name}.p5m.2"), pkg_mogrify)
    safesystem("cp", build_path("#{name}.p5m.2"), manifest_fn)

    # Evaluate dependencies.
    if !attributes[:no_auto_depends?]
	    pkgdepend_gen = safesystemout("pkgdepend", "generate",  "-md", "#{staging_path}",  manifest_fn)
      File.write(build_path("#{name}.p5m.3"), pkgdepend_gen)

      # Allow user to review added dependencies
      edit_file(build_path("#{name}.p5m.3")) if attributes[:edit?]

	    safesystem("pkgdepend", "resolve",  "-m", build_path("#{name}.p5m.3"))
      safesystem("cp", build_path("#{name}.p5m.3.res"), manifest_fn)
    end

    # Final format of manifest
    safesystem("pkgfmt", manifest_fn)

    # Final edit for lint check and packaging
    edit_file(manifest_fn) if attributes[:edit?]

    # Add any facets or actuators that are needed.
    # TODO(jcraig): add manpage actuator to enable install wo/ man pages

    # Verify the package.
    if attributes[:p5p_lint] then
      safesystem("pkglint", manifest_fn)
    end

    # Publish the package.
    repo_path = build_path("#{name}_repo")
    safesystem("pkgrepo", "create", repo_path)
    safesystem("pkgrepo", "set", "-s", repo_path, "publisher/prefix=#{attributes[:p5p_publisher]}")
    safesystem("pkgsend", "-s", repo_path,
      "publish", "-d", "#{staging_path}", "#{build_path}/#{name}.p5m")
    safesystem("pkgrecv", "-s", repo_path, "-a",
      "-d", build_path("#{name}.p5p"), name)

    # Test the package
    if attributes[:p5p_validate] then
      safesystem("pkg", "install",  "-nvg", build_path("#{name}.p5p"), name)
    end

    # Cleanup
    safesystem("mv", build_path("#{name}.p5p"), output_path)

  end # def output
end # class FPM::Package::IPS
