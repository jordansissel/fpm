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
  spec.version = "0.4.0"
  spec.summary = "fpm - package building and mangling"
  spec.description = "Convert directories, rpms, python eggs, rubygems, and " \
    "more to rpms, debs, solaris packages and more. Win at package " \
    "management without wasting pointless hours debugging bad rpm specs!"

  # For parsing JSON (required for some Python support, etc)
  # http://flori.github.com/json/doc/index.html
  spec.add_dependency("json") # license: Ruby License
  
  # For logging
  # https://github.com/jordansissel/ruby-cabin
  spec.add_dependency("cabin", "~> 0.4.2") # license: Apache 2 

  # For backports to older rubies
  # https://github.com/marcandre/backports
  spec.add_dependency("backports", "2.3.0") # license: MIT

  # For reading and writing rpms
  spec.add_dependency("arr-pm") # license: Apache 2

  # For simple shell/file hackery in the tests.
  # http://rush.heroku.com/rdoc/
  spec.add_development_dependency("rush") # license: MIT

  spec.add_development_dependency("rspec") # license: ???
  spec.add_development_dependency("insist") # license: ???

  spec.files = files
  spec.require_paths << "lib"
  spec.bindir = "bin"
  spec.executables << "fpm"
  spec.executables << "fpm-npm"

  spec.author = "Jordan Sissel"
  spec.email = "jls@semicomplete.com"
  spec.homepage = "https://github.com/jordansissel/fpm"
end

