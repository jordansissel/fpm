require "fpm/util"

class FPM::Recipe

  RECIPE_SECTIONS = [ :download,
                      :prebuild,
                      :build,
                      :install,
                    ]

  attr_accessor(*RECIPE_SECTIONS)

  def initialize(recipe_file)
    recipe_file = File.expand_path(recipe_file)

    unless File.file?(recipe_file)
      STDERR.puts "recipe file #{recipe_file} does not exist"
      exit 1
    end

    # parse recipe_file
    cur_section = nil
    cur_val = nil
    File.foreach(recipe_file) do |line|
      line.gsub!(/ *#.*| +$/, '')
      next if line =~ /^$/
      if section_name = section_tag?(line)
        if !cur_section # this is the first section tag we have seen.
          cur_section = section_name
          cur_val = ""
        else
          instance_variable_set("@#{cur_section}", cur_val)
          cur_section = section_name
          cur_val = ""
        end
      else # this line is not a section
        cur_val += line
      end
    end
    if cur_section and cur_val
      self.instance_variable_set("@#{cur_section}", cur_val)
    end
  end

  private
  def section_tag?(line)
    # Note that no trimming of +line+ happens here
    line[/^\[(#{RECIPE_SECTIONS.join("|")})\]$/, 1]
  end
end
