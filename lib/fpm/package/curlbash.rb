require "fpm/package"
require "json"

class FPM::Package::CurlBash < FPM::Package

  option "--container-image", "IMAGE", "The container image to use when running the command", :default => "ubuntu:latest"

  option "--setup", "SHELL COMMANDS", "Commands to run but not to include in the resulting package. For example, 'apt-get update' or other setup.", :multivalued => true

  #option "--volume", "VOLUME" , "Same syntax as `podman run --volume`. Mount a local directory into the container. Useful for `make install` types of projects that were built outside of fpm."

  def input(entry)
    build_flags = []

    if File.exists?(entry)
      if attributes[:curlbash_setup_list]
        logger.warn("When the argument given is a file or directory, the --curlbash-setup flags are ignored. This is because fpm assumes any setup you want to do is done inside of your Dockerfile or Containerfile, and also because fpm does not know how to edit a Dockerfile to append these setup steps.")
      end

      entryinfo = File.stat(entry)
      if entryinfo.file?
        build_flags += ["-f", entry, build_path]
      elsif entryinfo.directory?
        build_flags += [entry]
      else
        logger.fatal("The path must be a file or a directory. It is not.", :path => entry)
        raise FPM::InvalidPackageConfiguration, "The path must be a file or directory, but it is neither. Path: #{entry.inspect}"
      end
    else
      # The given argument is not a path, so let's assume it's a shell command to run.
      # We'll need to generate a 

      content = template("curlbash.erb").result(binding)
      containerfile = build_path("Containerfile")
      File.write(containerfile, content)

      build_flags += ["-f", build_path("Containerfile"), build_path]
    end

    name = "whatever-#{$$}"
    if program_exists?("podman")
      runtime = "podman"
    elsif program_exists?("docker")
      # Docker support isn't implemented yet. I don't expect it to be difficult, but
      # we need to check if the build, inspect, and save commands use the same syntax
      # At minimu, docker doesn't support the same flags as `podman image save`
      #runtime = "docker"
      logger.error("Docker executable found, but fpm doesn't support this yet. If you want this, file an issue? https://github.com/jordansissel/fpm/issues/new")
      raise FPM::Package::InvalidPackageConfiguration, "Missing 'podman' executable."
    else
      raise FPM::Package::InvalidPackageConfiguration, "Missing 'podman' executable."
    end

    safesystem(runtime, "image", "build", "-t", name, *build_flags)

    # Find out the identifier for the most latest image layer
    last_layer = nil
    execmd([runtime, "inspect", name], :stdin => false, :stdout =>true) do |stdout|
      inspection = JSON.parse(stdout.read)
      stdout.close
      last_layer = inspection[0]["RootFS"]["Layers"][-1]
    end

    # Convert the container to a image layer tarball.
    layerdir = build_path("layers")
    safesystem(runtime, "save", "--format", "docker-dir", "--output", layerdir, name)

    # Extract the last layer to the staging_path for packaging.
    safesystem("tar", "-C", staging_path, "-x", 
               "-f", build_path(File.join("layers", last_layer.gsub(/^sha256:/, ""))))

    (attributes[:excludes] ||= []).append(
      "tmp",
      "var/tmp",
      "root/.bashrc",
      "root/.profile",

      # Ignore podman's secrets files
      "run/secret/**",
      "run/secret",
      "run",
    )
  end
end
