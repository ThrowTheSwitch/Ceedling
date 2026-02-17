# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes'
require 'set'

# Parses GCC preprocessor output (with -fdirectives-only) to extract
# top-level include directives, distinguishing between user and system includes
class PreprocessorIncludesParser
  # Line marker format: # linenum filename flags
  # flags: 1=start of new file, 2=returning to a file, 3=system header, 4=implicit extern C
  LINE_MARKER_REGEX = /^#\s+(\d+)\s+"([^"]+)"(?:\s+(\d+(?:\s+\d+)*))?$/

  # Initialize parser with an IO buffer
  # @param io [IO] An IO object (File, StringIO, etc.) to read from
  def initialize(io)
    raise ArgumentError, "Expected an IO object, got #{io.class}" unless io.respond_to?(:each_line)
    @io = io
  end

  # Extracts top-level includes from the preprocessor output
  # Returns an array of UserInclude and SystemInclude objects
  # @param filepath [String, nil] Optional source filename to identify the initial file marker
  # @return [Array<UserInclude, SystemInclude>]
  def extract_includes(filepath: nil)
    includes = []
    nesting_level = 0
    seen_paths = Set.new
    initial_file_seen = false
    
    # Extract just the filename if a full path was provided
    source_filename = filepath ? File.basename(filepath) : nil
    
    @io.each_line do |line|
      # Match GCC line markers
      if (match = LINE_MARKER_REGEX.match(line))
        line_number = match[1].to_i
        filepath = match[2]
        flags = match[3] ? match[3].split.map(&:to_i) : []
        
        # Skip special markers like "<built-in>" and "<command-line>"
        next if filepath.start_with?('<')
        
        # The initial file marker is "# 1" followed by the source file being preprocessed
        # Match by filename if filepath was provided, otherwise use first real file
        if !initial_file_seen
          if line_number == 1 && (source_filename.nil? || File.basename(filepath) == source_filename)
            initial_file_seen = true
            nesting_level = 0
          end
          next
        end
        
        # Flag 1 means entering a new file
        if flags.include?(1)
          nesting_level += 1
          
          # Only capture includes at nesting level 1 (direct includes from original file)
          # and skip if we've already seen this path
          if nesting_level == 1 && !seen_paths.include?(filepath)
            seen_paths.add(filepath)
            
            # Flag 3 indicates a system header
            if flags.include?(3)
              includes << SystemInclude.new(filepath)
            else
              includes << UserInclude.new(filepath)
            end
          end
        # Flag 2 means returning to a previous file
        elsif flags.include?(2)
          nesting_level -= 1 if nesting_level > 0
        end
      end
    end
    
    return includes
  end


  # Parse preprocessor output from a file (production use)
  # @param filepath [String] Path to the preprocessor output file
  # @return [Array<UserInclude, SystemInclude>]
  def self.parse_file(filepath)
    File.open(filepath, 'r') do |file|
      parser = new(file)
      parser.extract_includes(filepath: filepath)
    end
  end

  # Parse preprocessor output from a string (testing use)
  # @param content [String] Preprocessor output as a string
  # @return [Array<UserInclude, SystemInclude>]
  def self.parse_string(content, filepath)
    require 'stringio'
    io = StringIO.new(content)
    parser = new(io)
    parser.extract_includes(filepath: filepath)
  end
end

# Command-line interface
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: #{File.basename($PROGRAM_NAME)} <preprocessor_output_file>"
    puts ""
    puts "Parses GCC preprocessor output and extracts top-level include directives."
    puts ""
    puts "Example:"
    puts "  gcc -E -fdirectives-only source.c -o output.i"
    puts "  #{File.basename($PROGRAM_NAME)} output.i"
    exit 1
  end

  filepath = ARGV[0]

  unless File.exist?(filepath)
    puts "Error: File not found: #{filepath}"
    exit 1
  end

  begin
    includes = PreprocessorIncludesParser.parse_file(filepath)
    
    puts "Found #{includes.length} top-level include(s):"
    puts ""
    
    user_includes = includes.select { |inc| inc.is_a?(UserInclude) }
    system_includes = includes.select { |inc| inc.is_a?(SystemInclude) }
    
    if user_includes.any?
      puts "User includes (#{user_includes.length}):"
      user_includes.each do |inc|
        puts "  #{inc}"
      end
      puts ""
    end
    
    if system_includes.any?
      puts "System includes (#{system_includes.length}):"
      system_includes.each do |inc|
        puts "  #{inc}"
      end
    end
    
  rescue => e
    puts "Error parsing file: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end
