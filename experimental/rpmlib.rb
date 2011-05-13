
class RPMFile 
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
    
    def read(file)
      # Use 'A' here instead of 'a' to trim nulls.
      data = file.read(96).unpack("A4CCnnA66nnA16")
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

    # is 'il' index length?
    attr_accessor :il     # rpmlib calls this field 'il' unhelpfully

    # what is 'dl' ?
    attr_accessor :dl     # rpmlib calls this field 'dl' unhelpfully

    def read(file)
      # Signature reads 16 bytes (4 x int32)
      data = file.read(16).unpack("a8NN")
      @magic, @il, @dl = data
      validate
      # data[0..1] is compared against rpm_header_magic
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

      if !(0..32).include?(@il)
        raise "Invalid 'il' value #{@il}, expected to be in range [0..32]"
      end

      if !(0..8192).include?(@dl)
        raise "Invalid 'il' value #{@dl}, expected to be in range [0..8192]"
      end
    end # def validate
  end # class ::RPMFile::Signature

  def lead
    if @lead.nil?
      @lead = ::RPMFile::Lead.new
      @lead.read(@file)
    end
    return @lead
  end # def lead

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

  def header
    # Not supported yet
    # http://docs.fedoraproject.org/en-US/Fedora_Draft_Documentation/0.1/html/RPM_Guide/ch15s03s03.html
  end
end # class RPMFile
