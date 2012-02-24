guard "minitest" do
  watch(%r{^test/.*/[^.][^/]+\.rb}) { |m| p m[0]; m[0] }
  watch(%r{^lib/(.*/[^.][^/]+\.rb)}) { |m| p m[0]; "test/#{m[1]}" }
  notification :libnotify, :timeout => 5, :transient => true, :append => false
end

