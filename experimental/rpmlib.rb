require "ap"

# Much of the code here is derived from knowledge gained by reading the rpm
# source code and this site:
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

  class Lead
    #struct rpmlead {
    attr_accessor :magic #unsigned char magic[4]; 
    attr_accessor :major #unsigned char major;
    attr_accessor :minor #unsigned char minor;
    attr_accessor :type  #short type;
    attr_accessor :archnum #short archnum;
    attr_accessor :name #char name[66];
    attr_accessor :osnum #short osnum;
    attr_accessor :signature_type #short signature_type;
    attr_accessor :reserved #char reserved[16];
    #}
    #
    attr_accessor :length

    def type
      case @type
      when 0
        return :binary
      when 1
        return :source
      else
        raise "Unknown package 'type' value #{@type}"
      end
    end # def type
    
    def read(file)
      # Use 'A' here instead of 'a' to trim nulls.
      @length = 96
      data = file.read(@length).unpack("A4CCnnA66nnA16")
      @magic, @major, @minor, @type, @archnum, @name, \
        @osnum, @signature_type, @reserved = data

      return nil
    end # def read

    def write(file)
      data = [ @magic, @major, @minor, @type, @archnum, @name, \
               @osnum, @signature_type, @reserved ].pack("a4CCnnA66nna16")
      file.write(data)
    end # def write
  end # class ::RPMFile::Lead

  class Signature
    HEADER_SIGNED_TYPE = 5
    HEADER_MAGIC = "\x8e\xad\xe8\x01\x00\x00\x00\x00"

    attr_accessor :magic  # 8-byte string magic
    attr_accessor :index_length  # rpmlib calls this field 'il' unhelpfully
    attr_accessor :data_length   # rpmlib calls this field 'dl' unhelpfully

    attr_accessor :length

    def read(file)
      # TODO(sissel): in RPM version major (@lead.major) < 3, there is no
      # header magic? RPM's code seems to confirm.

      # Signature reads 16 bytes (4 x int32)
      @length = 16
      data = file.read(@length).unpack("a8NN")
      @magic, @index_length, @data_length = data
      validate
      # data[0..1] is compared against HEADER_MAGIC
      # data[2] must be between [0, 32] inclusive
      # data[3] must be between [0, 8192] inclusive
    end # def raed

    def write(file)
    end # def write

    def validate
      # TODO(sissel): raise real exceptions
      if @magic != ::RPMFile::Signature::HEADER_MAGIC
        raise "Signature magic did not match; got #{@magic.inspect}, " \
              "expected #{::RPMFile::Signature::HEADER_MAGIC.inspect}"
      end

      if !(0..32).include?(@index_length)
        raise "Invalid 'index_length' value #{@index_length}, expected to be in range [0..32]"
      end

      if !(0..8192).include?(@data_length)
        raise "Invalid 'data_length' value #{@data_length}, expected to be in range [0..8192]"
      end
    end # def validate
  end # class ::RPMFile::Signature

  class Header
    attr_reader :tags
    attr_reader :length

    attr_accessor :magic  # 8-byte string magic
    attr_accessor :index_length  # rpmlib calls this field 'il' unhelpfully
    attr_accessor :data_length   # rpmlib calls this field 'dl' unhelpfully

    HEADER_MAGIC = "\x8e\xad\xe8\x01\x00\x00\x00\x00"

    def initialize(rpm)
      @rpm = rpm
      @tags = []
    end

    def read
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

      # Header always starts with HEADER_MAGIC + index_length(2bytes) +
      # data_length(2bytes)
      @length = 16
      data = @rpm.file.read(@length).unpack("a8NN")
      # TODO(sissel): @index_length is really a count, rename?
      @magic, @index_length, @data_length = data
      validate

      entry_size = 16 # tag id, type, offset, count == 16 bytes
      index_size = @index_length * entry_size
      tag_data = @rpm.file.read(index_size)
      data = @rpm.file.read(@data_length)

      (0 ... @index_length).each do |i|
        offset = i * entry_size
        entry_data = tag_data[i * entry_size, entry_size]
        entry = entry_data.unpack("NNNN")
        entry << entry_data
        tag = Tag.new(*entry)
        @tags << tag

        # TODO(sissel): This section is pretty F'd up.
        # Maybe I should just support RPM 3 (centos5 and fedora14 do it)
        if i == 0  # first tag
          # First tag must be <100 (if not, it is an 'old' package and
          # therefore we fabricate a 'region' tag that goes in first.
          if tag.tag_as_int >= 100 
            # I don't really feel like supporting this. If you need it, please let me know.
            raise "Unsupported RPM (Legacy RPM?)"
            # 7 == :binary (region tag type), 61 = :header_image
            #legacy_tag = Tag.new(7, 61, entry_size, 0 - @rpm.signature.data_length, data)
            #@tags.unshift(legacy_tag)
          end

          rdl = ril = nil
          if tag.offset > 0
            rdl = -(data[offset,1].unpack("C")).first
            ril = rdl / entry_size
          else
            ril = @rpm.signature.index_length
            rdl = ril * entry_size
            tag.tag = 61 # :header_image
          end
          tag.offset = -rdl
        end # first tag handling

        #ap tag.tag => {
          #:type => tag.type, 
          #:offset => tag.offset,
          #:count => tag.count,
          #:value => tag.value,
        #}
      end # each index
      #@length = (@rpm.signature.index_length * entry_size) + @rpm.signature.data_length
    end # def read

    def write
    end # def write

    def validate
      # TODO(sissel): raise real exceptions
      if @magic != ::RPMFile::Signature::HEADER_MAGIC
        raise "Signature magic did not match; got #{@magic.inspect}, " \
              "expected #{::RPMFile::Signature::HEADER_MAGIC.inspect}"
      end

      if !(0..32).include?(@index_length)
        raise "Invalid 'index_length' value #{@index_length}, expected to be in range [0..32]"
      end

      if !(0..8192).include?(@data_length)
        raise "Invalid 'data_length' value #{@data_length}, expected to be in range [0..8192]"
      end
    end # def validate
  end # class ::RPMFile::Header

  class Tag
    attr_accessor :tag
    attr_accessor :type
    attr_accessor :offset
    attr_accessor :count

    # This data can be found mostly in rpmtag.h
    TAG = {
      61 => :header_image,
      62 => :signature,
      267 => :dsa,
      268 => :rsa,
      269 => :sha1,
      1000 => :name,
      1002 => :release,
      1004 => :summary,
      1005 => :description,
      1007 => :buildhost,
      1124 => :payload_format,
      1125 => :payload_compressor,
    }

    # See 'rpmTagType' enum in rpmtag.h
    TYPE = {
      0 => :null,
      1 => :char,
      2 => :int8,
      3 => :int16,
      4 => :int32,
      5 => :int64,
      6 => :string,
      7 => :binary,
      8 => :string_array,
      9 => :i18nstring,
    }

    def initialize(tag_id, type, offset, count, data)
      @tag = tag_id
      @type = type
      @offset = offset
      @count = count

      @data = data
    end # def initialize

    def tag
      Tag::TAG[@tag] or @tag
    end # def tag

    def tag_as_int
      @tag
    end

    def type
      Tag::TYPE[@type] or @type
    end # def type

    def value
      case type
        when :string
          return @data[@offset .. -1].gsub(/\0.*/, "")
        when :binary
          return @data[@offset, @count]
        when :int32
          return @data[@offset, 4].unpack("N")
        when :int16
          return @data[@offset, 2].unpack("n")
      end
    end # def value
  end # class Tag

  public
  def lead
    if @lead.nil?
      @lead = ::RPMFile::Lead.new
      @lead.read(@file)
    end
    return @lead
  end # def lead

  public
  def signature
    lead

    # If signature_type is not 5 (HEADER_SIGNED_TYPE), no signature.
    if @lead.signature_type != Signature::HEADER_SIGNED_TYPE
      @signature = false
      return
    end

    if @signature.nil?
      @signature = ::RPMFile::Signature.new
      @signature.read(@file)
    end

    return @signature
  end # def signature

  public
  def header
    #signature
    lead
    if @header.nil?
      @header = ::RPMFile::Header.new(self)
      @header.read
    end
    return @header
    # http://docs.fedoraproject.org/en-US/Fedora_Draft_Documentation/0.1/html/RPM_Guide/ch15s03s03.html
  end

  # Returns a file descriptor. On first invocation, it seeks to the start of the payload
  public
  def payload
    header
    if @payload.nil?
      @payload = @file.clone
      @payload.seek(@lead.length + @signature.length + @header.length, IO::SEEK_SET)
    end

    return @payload
  end # def payload
end # class RPMFile
