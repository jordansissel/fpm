#!/usr/bin/env ruby
$: << File.join(File.dirname(__FILE__), "..", "..", "lib")

# This example uses the API to create a package from local files
# it also creates necessary init-scripts and systemd files so our executable can be used as a service

require "fpm"
require "tmpdir"
require "fpm/package/pleaserun"

# enable logging
FPM::Util.send :module_function, :logger
FPM::Util.logger.level = :info
FPM::Util.logger.subscribe STDERR

package = FPM::Package::Dir.new

# Set some attributes
package.name = "my-service"
package.version = "1.0"

# Add a script to run after install (should be in the current directory):
package.scripts[:after_install] = 'my_after_install_script.sh'

# Example for adding special attributes
package.attributes[:deb_group] = "super-useful"
package.attributes[:rpm_group] = "super-useful"

# Add our files (should be in the current directory):
package.input("my-executable=/usr/bin/")
package.input("my-library.so=/usr/lib/")

# Now, add our init-scripts, systemd services, and so on:
pleaserun = package.convert(FPM::Package::PleaseRun)
pleaserun.input ["/usr/bin/my-executable", "--foo-from", "bar"]

# Create two output packages!
output_packages = []
output_packages << pleaserun.convert(FPM::Package::RPM)
output_packages << pleaserun.convert(FPM::Package::Deb)

# and write them both.
begin
  output_packages.each do |output_package|
    output = output_package.to_s
    output_package.output(output)

    puts "successfully created #{output}"
  end
ensure
  # defer cleanup until the end
  output_packages.each {|p| p.cleanup}
end
