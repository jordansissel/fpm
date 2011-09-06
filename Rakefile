task :default => [:package]

task :test do
  system("make -C test")
end

task :package => [:test, :package_real]  do
end

task :package_real do
  system("gem build fpm.gemspec")
end

task :publish do
  latest_gem = %x{ls -t fpm*.gem}.split("\n").first
  system("gem push #{latest_gem}")
end
