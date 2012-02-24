guard "minitest" do
  watch(%r{^test/.*/[^.][^/]+\.rb}) { |m| system("ruby #{m[0]}") }
  watch(%r{^lib/(.*/[^.][^/]+\.rb)}) { |m| system("ruby test/#{m[1]}") }
  notification :libnotify, :timeout => 5, :transient => true, :append => false
end

