require "spec_setup"
require "fpm" # local
require "fpm/package/gem" # local

describe FPM::Package::Nuget do
  let (:example_nuget) do
    File.expand_path("../../fixtures/nuget/example/example-1.0.nuget", File.dirname(__FILE__))
  end

  after :each do
    subject.cleanup
  end

end # describe FPM::Package::Nuget
