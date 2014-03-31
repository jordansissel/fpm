require "fpm/package/zip"

# NuGet Package type.
#
# Build NuGets without having to waste hours reading the NuSpec reference.
# Well, in case you want to read it, here: http://docs.nuget.org/docs/reference/nuspec-reference
#
class FPM::Package::Nuget < FPM::Package::Zip

  # Nuget as input is inherited from Zip.

  # Output a nuget package.
  def output(output_path)
    output_check(output_path)
    # Abort if the target path already exists.

    write_nuspec

    with(File.expand_path(output_path)) do |output_path|
      ::Dir.chdir(staging_path) do
        files = Find.find('.').to_a
        safesystem("zip", output_path, *files)
      end
    end

  end # def output

  def write_nuspec
    # Write the nuspec file <name>.<version>.nuspec
    with(staging_path("#{name}.#{version}.nuspec")) do |nuspec|
      nuspec_data = template("nuspec.erb").result(binding)

      @logger.debug("Writing nuspec file", :path => nuspec)
      File.write(nuspec, nuspec_data)
    end
  end # def write_nuspec

  def to_s(format=nil)
    # Default format if nil
    # git_1.7.9.nuget
    return super("NAME_VERSION.TYPE") if format.nil?
    return super(format)
  end # def to_s

end