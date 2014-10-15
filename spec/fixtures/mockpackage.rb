require "fpm/namespace"
require "fpm/package"

class FPM::Package::Mock < FPM::Package
  def input(*args); end
  def output(*args); end
end
