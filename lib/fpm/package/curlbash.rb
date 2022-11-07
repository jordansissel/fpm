
class FPM::Package::CurlBash < FPM::Package

  option "--container-image", "IMAGE", "The container image to use when running the command", :default => "ubuntu:latest"

  option "--setup", "SHELL COMMANDS", "Commands to run but not to include in the resulting package. For example, 'apt-get update' or other setup.", :multivalued => true

  def input(command)
    name = "whatever-#{$$}"

    content = template("curlbash.erb").result(binding)
    containerfile = build_path("Containerfile")
    File.write(containerfile, content)

    safesystem("podman", "image", "build", "-t", name, build_path)

    # Convert the container to a image layer tarball.
    changes_tar = build_path("changes.tar")
    safesystem("podman", "save", name, "-o", changes_tar)

    last_layer = nil
    execmd(["podman", "inspect", name], :stdin => false, :stdout =>true) do |stdout|
      inspection = JSON.parse(stdout.read)
      stdout.close
      last_layer = inspection[0]["RootFS"]["Layers"][-1]
    end

    layerdir = build_path("layers")
    safesystem("podman", "save", "--format", "docker-dir", "--output", layerdir, name)

    # Extract the last layer to the staging_path for packaging.
    safesystem("tar", "-C", staging_path, "-xf", build_path(File.join("layers", last_layer.gsub(/^sha256:/, ""))))
  end
end
