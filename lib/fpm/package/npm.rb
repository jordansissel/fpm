require "fpm/namespace"
require "fpm/package"
require "fpm/util"
require "fileutils"

class FPM::Package::NPM < FPM::Package
  # Flags '--foo' will be accessable  as attributes[:npm_foo]
  option "--bin", "NPM_EXECUTABLE",
    "The path to the npm executable you wish to run.", :default => "npm"

  option "--package-name-prefix", "PREFIX", "Name to prefix the package " \
    "name with.", :default => "node"

  private
  def input(package)
    # Notes:
    # * npm respects PREFIX
    settings = {
      "cache" => build_path("npm_cache"),
      "loglevel" => "silent"
    }

    if attributes.include?(:prefix) && !attributes[:prefix].nil?
      settings["prefix"] = staging_path(attributes[:prefix])
    else
      @logger.info("Setting default npm install prefix",
                   :prefix => "/usr/local/lib")
      settings["prefix"] = staging_path("/usr/local/lib")
    end

    fakehome = build_path("home")
    ::Dir.mkdir(fakehome) if !::Dir.exists?(fakehome)

    original_home = ENV["HOME"]
    ENV["HOME"] = fakehome
    settings.each do |key, value|
      @logger.debug("Configuring npm", key => value)
      safesystem(attributes[:npm_bin], "config", "set", key, value)
    end

    install_args = [
      attributes[:npm_bin],
      "install",
      # use 'package' or 'package@version'
     (version ? "#{package}@#{version}" : package)
    ]

    # The only way to get npm to respect the 'prefix' setting appears to
    # be to set the --global flag.
    install_args << "--global"

    safesystem(*install_args)

    # Query 
    npm_ls = JSON.parse(`#{attributes[:npm_bin]} ls --json --long #{package}`)
    p npm_ls
    name, info = npm_ls["dependencies"].first

    self.name = [attributes[:npm_package_name_prefix], name].join("-")
    self.version = info["version"]

    if info.include?("repository")
      self.url = info["repository"]["url"]
    else
      self.url = "https://npmjs.org/package/#{self.name}"
    end

    self.description = info["description"]
    self.vendor = sprintf("%s <%s>", info["author"]["name"],
                          info["author"]["email"])

    # npm installs dependencies in the module itself, so if you do
    # 'npm install express' it installs dependencies (like 'connect')
    # to: node_modules/express/node_modules/connect/...
    #
    # To that end, I don't think we necessarily need to include 
    # any automatic dependency information since every 'npm install'
    # is fully self-contained.
    #
    # It's possible someone will want to decouple that in the future,
    # but I will wait for that feature request.

    # Restore the original HOME setting
    ENV["HOME"] = original_home 
  end

  public(:input)
end # class FPM::Package::NPM
