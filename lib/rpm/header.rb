require File.join(File.dirname(__FILE__), "namespace")
require File.join(File.dirname(__FILE__), "tag")

class RPMFile::Header
  attr_reader :tags
  attr_reader :length

  attr_accessor :magic  # 8-byte string magic
  attr_accessor :index_count  # rpmlib calls this field 'il' unhelpfully
  attr_accessor :data_length   # rpmlib calls this field 'dl' unhelpfully

  HEADER_SIGNED_TYPE = 5
  HEADER_MAGIC = "\x8e\xad\xe8\x01\x00\x00\x00\x00"

  def initialize(rpm)
    @rpm = rpm
    @tags = []
  end

  def read
    # TODO(sissel): update the comments here to reflect learnings about rpm
    # internals
    # At this point assume we've read and consumed the lead and signature.
    #len = @rpm.signature.index_length + @rpm.signature
    #
    # header size is
    #     ( @rpm.signature.index_length * size of a header entry )
    #     + @rpm.signature.data_length
    #
    # header 'entries' are an
    #   int32 (tag id), int32 (tag type), int32  (offset), uint32 (count)
    #
    # See rpm's header.c, the headerLoad method function for reference.

    # Header always starts with HEADER_MAGIC + index_count(2bytes) +
    # data_length(2bytes)
    data = @rpm.file.read(16).unpack("a8NN")
    # TODO(sissel): @index_count is really a count, rename?
    @magic, @index_count, @data_length = data
    validate

    entry_size = 16 # tag id, type, offset, count == 16 bytes
    @index_size = @index_count * entry_size
    tag_data = @rpm.file.read(@index_size)
    data = @rpm.file.read(@data_length)

    #ap :data => data

    (0 ... @index_count).each do |i|
      offset = i * entry_size
      entry_data = tag_data[i * entry_size, entry_size]
      entry = entry_data.unpack("NNNN")
      entry << data
      tag = ::RPMFile::Tag.new(*entry)
      @tags << tag

      #ap tag.tag => {
        #:type => tag.type,
        #:offset => tag.offset,
        #:count => tag.count,
        #:value => (tag.value rescue "???"),
      #}
    end # each index
    @length = @magic.size + @index_size + @data_length
  end # def read

  def write
    raise "not implemented yet"
    # Sort tags by type (integer value)
    # emit all tags in order
    # then emit all data segments in same order
  end # def write

  def validate
    # TODO(sissel): raise real exceptions
    if @magic != ::RPMFile::Header::HEADER_MAGIC
      raise "Header magic did not match; got #{@magic.inspect}, " \
            "expected #{::RPMFile::Header::HEADER_MAGIC.inspect}"
    end

    #if !(0..32).include?(@index_count)
      #raise "Invalid 'index_count' value #{@index_count}, expected to be in range [0..32]"
    #end

    #if !(0..8192).include?(@data_length)
      #raise "Invalid 'data_length' value #{@data_length}, expected to be in range [0..8192]"
    #end
  end # def validate
end # class RPMFile::Header
