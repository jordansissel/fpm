require File.join(File.dirname(__FILE__), "lib/fpm/version")
Gem::Specification.new do |spec|
  files = []
  dirs = %w{lib bin templates}
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  files << "LICENSE"
  files << "CONTRIBUTORS"
  files << "CHANGELOG.rst"

  files = files.reject { |path| path =~ /\.pyc$/ }

  spec.name = "fpm"
  spec.version = FPM::VERSION
  spec.summary = "fpm - package building and mangling"
  spec.description = "Convert directories, rpms, python eggs, rubygems, and " \
    "more to rpms, debs, solaris packages and more. Win at package " \
    "management without wasting pointless hours debugging bad rpm specs!"
  spec.license = "MIT-like"

  # For parsing JSON (required for some Python support, etc)
  # http://flori.github.com/json/doc/index.html
  spec.add_dependency("json", ">= 1.7.7", "< 2.0") # license: Ruby License

  # For logging
  # https://github.com/jordansissel/ruby-cabin
  spec.add_dependency("cabin", ">= 0.6.0") # license: Apache 2

  # For backports to older rubies
  # https://github.com/marcandre/backports
  spec.add_dependency("backports", ">= 2.6.2") # license: MIT

  # For reading and writing rpms
  spec.add_dependency("arr-pm", "~> 0.0.10") # license: Apache 2

  # For command-line flag support
  # https://github.com/mdub/clamp/blob/master/README.markdown
  spec.add_dependency("clamp", "~> 1.0.0") # license: MIT

  # For starting external processes across various ruby interpreters
  spec.add_dependency("childprocess") # license: ???

  # For calling functions in dynamic libraries
  spec.add_dependency("ffi") # license: GPL3/LGPL3

  spec.add_development_dependency("rake", "~> 10") # license: MIT

  # For creating tar archives (many packages are just tar archives)
  spec.add_dependency("minitar") # license: GPL2+

  # For creating FreeBSD package archives (xz-compressed tars)
  spec.add_dependency("ruby-xz") # license: MIT

  # For sourcing from pleaserun 
  spec.add_dependency("pleaserun", "~> 0.0.24") # license: Apache 2

  spec.add_development_dependency("rspec", "~> 3.0.0") # license: MIT (according to wikipedia)
  spec.add_development_dependency("insist", "~> 1.0.0") # license: Apache 2
  spec.add_development_dependency("pry")
  spec.add_development_dependency("stud")

  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "fpm"

  spec.author = "Jordan Sissel"
  spec.email = "jls@semicomplete.com"
  spec.homepage = "https://github.com/jordansissel/fpm"
end

