require 'rubygems/package'

require 'stringio'

module FPM
  module Issues
    module TarWriter
      # See https://github.com/rubygems/rubygems/issues/1608
      def self.has_issue_1608?
        name, prefix = nil,nil
        io = StringIO.new
        ::Gem::Package::TarWriter.new(io) do |tw|
          name, prefix = tw.split_name('/123456789'*9 + '/1234567890') # abs name 101 chars long
        end
        return prefix.empty?
      end

      def self.has_issues_with_split_name?
        return false unless ::Gem::Package::TarWriter.method_defined?(:split_name)
        return has_issue_1608?
      end

      def self.has_issues_with_add_symlink?
        return !::Gem::Package::TarWriter.public_instance_methods.include?(:add_symlink)
      end
    end # module TarWriter
  end # module Issues
end # module FPM

module FPM; module Util; end; end

# Like the ::Gem::Package::TarWriter but contains some backports/latest and bug fixes
class FPM::Util::TarWriter < ::Gem::Package::TarWriter
  if FPM::Issues::TarWriter.has_issues_with_split_name?
    def split_name(name)
      if name.bytesize > 256 then
        raise ::Gem::Package::TooLongFileName.new("File \"#{name}\" has a too long path (should be 256 or less)")
      end

      prefix = ''
      if name.bytesize > 100 then
        parts = name.split('/', -1) # parts are never empty here
        name = parts.pop            # initially empty for names with a trailing slash ("foo/.../bar/")
        prefix = parts.join('/')    # if empty, then it's impossible to split (parts is empty too)
        while !parts.empty? && (prefix.bytesize > 155 || name.empty?)
          name = parts.pop + '/' + name
          prefix = parts.join('/')
        end

        if name.bytesize > 100 or prefix.empty? then
          raise ::Gem::Package::TooLongFileName.new("File \"#{prefix}/#{name}\" has a too long name (should be 100 or less)")
        end

        if prefix.bytesize > 155 then
          raise ::Gem::Package::TooLongFileName.new("File \"#{prefix}/#{name}\" has a too long base path (should be 155 or less)")
        end
      end

      return name, prefix
    end
  end # if FPM::Issues::TarWriter.spit_name_has_issues?

  if FPM::Issues::TarWriter.has_issues_with_add_symlink?
    # Backport Symlink Support to TarWriter
    # https://github.com/rubygems/rubygems/blob/4a778c9c2489745e37bcc2d0a8f12c601a9c517f/lib/rubygems/package/tar_writer.rb#L239-L253
    def add_symlink(name, target, mode)
      check_closed

      name, prefix = split_name name

      header = ::Gem::Package::TarHeader.new(:name => name, :mode => mode,
                                             :size => 0, :typeflag => "2",
                                             :linkname => target,
                                             :prefix => prefix,
                                             :mtime => Time.now).to_s

      @io.write header

      self
    end # def add_symlink
  end
end
