require "fpm/namespace"

require "fpm/package"

packages_list = Dir.entries "fpm/package"
packages_list.each do |package_file|
  require "fpm/package/#{package_file.gsub(".rb", "")}"
end
