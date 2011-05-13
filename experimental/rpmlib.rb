
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
      data = file.read(96).unpack("A4CCssA66ssA16")
      @magic, @major, @minor, @type, @archnum, @name, \
        @osnum, @signature_type, @reserved = data
      return nil
    end # def read

    def write(file)
      data = [ @magic, @major, @minor, @type, @archnum, @name, \
               @osnum, @signature_type, @reserved ].pack("A4CCssA66ssA16")
      file.write(data)
    end # def write
  end # class ::RPMFile::Lead

  def lead
    if @lead.nil?
      @lead = ::RPMFile::Lead.new
      @lead.read(@file)
    end
    return @lead
  end # def lead
end # class RPMFile
