require "fpm/source_package"
require "fileutils"

class FPM::Package::SRPM < FPM::SourcePackage

  def output(output_path)
    output_check(output_path)

    %w(BUILD RPMS SRPMS SOURCES SPECS).each { |d| FileUtils.mkdir_p(build_path(d)) }

    spec_file = staging_path("#{name}.spec")
    # puts "spec_file = #{spec_file}"

    File.open(spec_file, "w+") do |file|

      if name = name()
        file.write("Name: #{name}\n")
      end

      if version = version()
        file.write("Version: #{version}\n")
      end

      if license = license()
        file.write("License: #{license}\n")
      end

      if release = iteration()
        file.write("Release: #{release}\n")
      else
        file.write("Release: 1\n")
      end

      if download_url = recipe.download
        download_source(download_url.chomp, build_path("SOURCES"))
        file.write("Url: #{download_url}\n")
        file.write("Source0: #{download_url}\n")
      end

      if summary = description()
        file.write("Summary: #{summary}\n")
        file.write("%description\n#{summary}\n\n")
      end

      if prebuild_instructions = recipe.prebuild
        file.write("%prep\n#{prebuild_instructions}\n\n")
      end

      if build_instructions = recipe.build
        file.write("%build\n#{build_instructions}\n\n")
      end

      if install_instructions = recipe.install
        file.write("%install\n#{install_instructions}\n\n")
      end
    end

    safesystem("rpmbuild", "-bs", "--define", "_topdir #{build_path}", spec_file)

    ::Dir["#{build_path}/SRPMS/*.src.rpm"].each do |srpm|
      FileUtils.cp(srpm, output_path)
    end
  end
end
