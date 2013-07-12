require File.join(File.dirname(__FILE__), "lib/fpm/version")
Gem::Specification.new do |spec|
  files = []
  dirs = %w{lib bin templates}
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  files << "LICENSE"
  files << "CONTRIBUTORS"
  files << "CHANGELIST"

  spec.name = "fpm"
  spec.version = FPM::VERSION
  spec.summary = "fpm - package building and mangling"
  spec.description = "Convert directories, rpms, python eggs, rubygems, and " \
    "more to rpms, debs, solaris packages and more. Win at package " \
    "management without wasting pointless hours debugging bad rpm specs!"

  # For parsing JSON (required for some Python support, etc)
  # http://flori.github.com/json/doc/index.html
  spec.add_dependency("json", ">= 1.7.7") # license: Ruby License
  
  # For logging
  # https://github.com/jordansissel/ruby-cabin
  spec.add_dependency("cabin", ">= 0.6.0") # license: Apache 2 

  # For backports to older rubies
  # https://github.com/marcandre/backports
  spec.add_dependency("backports", ">= 2.6.2") # license: MIT

  # For reading and writing rpms
  spec.add_dependency("arr-pm", "~> 0.0.8") # license: Apache 2

  # For http stuff
  spec.add_dependency("ftw", "~> 0.0.30") # license: Apache 2

  # For command-line flag support
  # https://github.com/mdub/clamp/blob/master/README.markdown
  spec.add_dependency("clamp", "~> 0.6") # license: MIT

  # For starting external processes across various ruby interpreters
  spec.add_dependency("childprocess") # license: ???

  spec.add_development_dependency("rspec") # license: MIT (according to wikipedia)
  spec.add_development_dependency("insist", "~> 0.0.5") # license: ???
  spec.add_development_dependency("minitest")
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

