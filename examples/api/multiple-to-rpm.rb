$: << File.join(File.dirname(__FILE__), "..", "..", "lib")
require "fpm"

package = FPM::Package::Gem.new
ARGV.each do |gem|
  name, version = gem.split(/[=]/, 2)
  package.version = version  # Allow specifying a specific version
  package.input(gem)
end
rpm = package.convert(FPM::Package::RPM)
rpm.name = "rubygem-manythings"
rpm.version = "1.0"
begin
  output = "NAME-VERSION.ARCH.rpm"
  rpm.output(rpm.to_s(output))
ensure
  rpm.cleanup
end
