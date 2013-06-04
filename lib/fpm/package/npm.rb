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
      "loglevel" => "warn",
      "global" => "true"
    }

    if attributes.include?(:prefix) && !attributes[:prefix].nil?
      settings["prefix"] = staging_path(attributes[:prefix])
    else
      @logger.info("Setting default npm install prefix",
                   :prefix => "/usr/local")
      settings["prefix"] = staging_path("/usr/local")
    end

    FileUtils.mkdir_p(settings["prefix"])

    npm_flags = []
    settings.each do |key, value|
      # npm lets you specify settings in a .npmrc but the same key=value settings
      # are valid as '--key value' command arguments to npm. Woo!
      @logger.debug("Configuring npm", key => value)
      npm_flags += [ "--#{key}", value ]
    end

    install_args = [
      attributes[:npm_bin],
      "install",
      # use 'package' or 'package@version'
     (version ? "#{package}@#{version}" : package)
    ]

    # The only way to get npm to respect the 'prefix' setting appears to
    # be to set the --global flag.
    #install_args << "--global"
    install_args += npm_flags

    safesystem(*install_args)

    # Query details about our now-installed package.
    # We do this by using 'npm ls' with json + long enabled to query details
    # about the installed package.
    npm_ls_out = safesystemout(attributes[:npm_bin], "ls", "--json", "--long", *npm_flags)
    npm_ls = JSON.parse(npm_ls_out)
    name, info = npm_ls["dependencies"].first

    self.name = [attributes[:npm_package_name_prefix], name].join("-")
    self.version = info.fetch("version", "0.0.0")

    if info.include?("repository")
      self.url = info["repository"]["url"]
    else
      self.url = "https://npmjs.org/package/#{self.name}"
    end

    self.description = info["description"]
    # Supposedly you can upload a package for npm with no author/author email 
    # so I'm being safer with this
    if info.include?("author")
      author_info = info["author"]
      self.vendor = sprintf("%s <%s>", author_info.fetch("name", "unknown"),
                            author_info.fetch("email", "unknown@unknown.unknown"))
    else
      self.vendor = "Unknown <unknown@unknown.unknown>"
    end

    # npm installs dependencies in the module itself, so if you do
    # 'npm install express' it installs dependencies (like 'connect')
    # to: node_modules/express/node_modules/connect/...
    #
    # To that end, I don't think we necessarily need to include 
    # any automatic dependency information since every 'npm install'
    # is fully self-contained. That's why you don't see any bother, yet,
    # to include the package's dependencies in here.
    #
    # It's possible someone will want to decouple that in the future,
    # but I will wait for that feature request.
  end

  public(:input)
end # class FPM::Package::NPM
