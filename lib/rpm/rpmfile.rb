require "ap"
require File.join(File.dirname(__FILE__), "namespace")
require File.join(File.dirname(__FILE__), "header")
require File.join(File.dirname(__FILE__), "lead")
require File.join(File.dirname(__FILE__), "tag")

# Much of the code here is derived from knowledge gained by reading the rpm
# source code, but mostly it started making more sense after reading this site:
# http://www.rpm.org/max-rpm/s1-rpm-file-format-rpm-file-format.html

class RPMFile
  attr_reader :file

  def initialize(file)
    if file.is_a?(String)
      file = File.new(file, "r")
    end
    @file = file

    # Make sure we're at the beginning of the file.
    @file.seek(0, IO::SEEK_SET)
  end # def initialize

  public
  def lead
    if @lead.nil?
      @lead = ::RPMFile::Lead.new(self)
      @lead.read
    end
    return @lead
  end # def lead

  public
  def signature
    lead # Make sure we've parsed the lead...

    # If signature_type is not 5 (HEADER_SIGNED_TYPE), no signature.
    if @lead.signature_type != Header::HEADER_SIGNED_TYPE
      @signature = false
      return
    end

    if @signature.nil?
      @signature = ::RPMFile::Header.new(self)
      @signature.read
    end

    return @signature
  end # def signature

  public
  def header
    signature

    # Skip 4 bytes of nulls
    # Why? I have no idea yet.
    if @file.read(4) != "\0\0\0\0"
      raise "Expected 4 nulls."
    end

    if @header.nil?
      @header = ::RPMFile::Header.new(self)
      @header.read
    end
    return @header
  end

  # Returns a file descriptor. On first invocation, it seeks to the start of the payload
  public
  def payload
    header
    if @payload.nil?
      @payload = @file.clone
      # TODO(sissel): Why +20? I have no idea. Needs more digging. Clearly I'm missing a part
      # of the file here.
      @payload.seek(@lead.length + @signature.length + @header.length + 20, IO::SEEK_SET)
    end

    return @payload
  end # def payload
end # class RPMFile
