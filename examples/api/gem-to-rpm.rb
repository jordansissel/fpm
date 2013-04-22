$: << File.join(File.dirname(__FILE__), "..", "..", "lib")
require "fpm"

package = FPM::Package::Gem.new

# the Gem package takes a string name of the package to download/install.
# Example, run this script with 'rails' as an argument and it will convert
# the latest 'rails' gem into rpm. 
package.input(ARGV[0])
rpm = package.convert(FPM::Package::RPM)
begin
  output = "NAME-VERSION.ARCH.rpm"
  rpm.output(rpm.to_s(output))
ensure
  rpm.cleanup
end
