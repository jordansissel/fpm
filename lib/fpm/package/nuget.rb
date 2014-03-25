require "fpm/package/zip"

# NuGet Package type.
#
# Build NuGets without having to waste hours reading the NuSpec reference.
# Well, in case you want to read it, here: http://docs.nuget.org/docs/reference/nuspec-reference
#
class FPM::Package::Nuget < FPM::Package::Zip

  # Output a zip file.
  def output(output_path)
    output_check(output_path)

    files = Find.find(staging_path).to_a
    write_nuspec
    safesystem("zip", output_path, *files)
  end # def output

  def write_nuspec
    nuspec_data = template("nuspec.erb").result(binding)

    @logger.debug("Writing nuspec file", :path => nuspec)
    File.write(nuspec, nuspec_data)
  end
end