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
  spec.add_dependency("json", ">= 1.6.6") # license: Ruby License
  
  # For logging
  # https://github.com/jordansissel/ruby-cabin
  spec.add_dependency("cabin", ">= 0.6.0") # license: Apache 2 

  # For backports to older rubies
  # https://github.com/marcandre/backports
  spec.add_dependency("backports", "2.6.2") # license: MIT

  # For reading and writing rpms
  spec.add_dependency("arr-pm", "~> 0.0.7") # license: Apache 2

  # For command-line flag support
  # https://github.com/mdub/clamp/blob/master/README.markdown
  spec.add_dependency("clamp", "0.3.1") # license: MIT

  # For starting external processes that give access to stdout, stderr and exit
  # status (open3 in ruby 1.8.7's stdlib doesn't properly set $?)
  spec.add_dependency("open4") # license: Ruby License

  # For simple shell/file hackery in the tests. 
  # http://rush.heroku.com/rdoc/
  spec.add_development_dependency("rush") # license: MIT

  spec.add_development_dependency("rspec") # license: MIT (according to wikipedia)
  spec.add_development_dependency("insist", "~> 0.0.5") # license: ???

  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "fpm"
  spec.executables << "fpm-npm"

  spec.author = "Jordan Sissel"
  spec.email = "jls@semicomplete.com"
  spec.homepage = "https://github.com/jordansissel/fpm"
end

