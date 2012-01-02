require 'rake/testtask'

task :default => [:package]

task :test do
  system("make -C test")
  Rake::Task[:minitest].invoke # Run these tests as well.
  # Eventually all the tests should be minitest-run or initiated.
end

# MiniTest tests
Rake::TestTask.new do |t|
  t.pattern = 'test/fpm/*.rb'
  t.name = 'minitest'
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
