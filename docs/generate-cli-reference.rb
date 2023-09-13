#!/usr/bin/env ruby

require_relative "../lib/fpm/command"

flagsort = lambda { |x| x.sub(/^--(?:\[no-\])?/, "") }

if ARGV.length == 0
  puts "Command-line Reference"
  puts "=========================="
  puts

  puts "This page documents the command-line flags available in FPM. You can also see this content in your terminal by running ``fpm --help``"
  puts

  puts "General Options"
  puts "---------------"

  FPM::Command.instance_variable_get(:@declared_options).sort_by { |o| flagsort.call(o.switches.first) }.each do |option|
      text = option.description.gsub("\n", " ")

      if option.type == :flag
          # it's a flag which means there are no parameters to the option
          puts "* ``#{option.switches.first}``"
      else
          puts "* ``#{option.switches.first} #{option.type}``"
      end

      if option.switches.length > 1
          puts "    - Alternate option spellings: ``#{option.switches[1..-1].join(", ")}``"
      end
      puts "    - #{text}"
      puts
  end
end


FPM::Package.types.sort_by { |k,v| k }.each do |name, type|
    next if ARGV.length > 0 && ARGV[0].downcase != name.downcase

    options = type.instance_variable_get(:@options)

    # Only print the section header if no arguments are given
    # -- aka, generate the list of all flags grouped by package type.
    if ARGV.length == 0
      puts "#{name}"
      puts "-" * name.size
      puts
    end

    if options.empty?
        puts "This package type has no additional options"
    end

    options.sort_by { |flag, _| flagsort.call(flag.first) }.each do |flag, param, help, options, block|
        if param == :flag 
            puts "* ``#{flag.first}``"
        else
            puts "* ``#{flag.first} #{param}``"
        end

        text = help.sub(/^\([^)]+\) /, "")
        puts "    - #{text}"
    end

    puts
end
