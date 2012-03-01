$: << File.join(File.dirname(__FILE__), "..", "..", "lib")
require "fpm"

package = FPM::Package::Gem.new
package.input(ARGV[0])
rpm = package.convert(FPM::Package::RPM)
begin
  output = "NAME-VERSION.ARCH.rpm"
  rpm.output(rpm.to_s(output))
ensure
  rpm.cleanup
end
