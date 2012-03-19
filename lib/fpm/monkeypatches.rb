# Copied from https://raw.github.com/marcandre/backports/master/lib/backports/1.9.3/io.rb
# Also Hacked just to make it work
# This is necessary until a newer version of backports (> 2.3.0) is available
class << IO
  # Standard in Ruby 1.9.3 See official documentation[http://ruby-doc.org/core-1.9.3/IO.html#method-c-write]
  def write(name, string, offset = nil, options = Backports::Undefined)
    File.open(name, "w") do |fd|
      fd.write(string)
    end
  end unless method_defined? :write
end
