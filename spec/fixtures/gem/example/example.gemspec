Gem::Specification.new do |spec|
  spec.name = "example"
  spec.version = "1.0"
  spec.summary = "sample summary"
  spec.description = "sample description"

  spec.add_dependency("dependency1") # license: Ruby License
  spec.add_dependency("dependency2")

  #spec.files = ["hello.txt"]
  spec.files = []
  #spec.require_paths << "lib"

  spec.author = "sample author"
  spec.email = "sample email"
  spec.homepage = "http://sample-url/"
end

