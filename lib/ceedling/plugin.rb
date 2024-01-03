
class String
  # reformat a multiline string to have given number of whitespace columns;
  # helpful for formatting heredocs
  def left_margin(margin=0)
    non_whitespace_column = 0
    new_lines = []
    
    # find first line with non-whitespace and count left columns of whitespace
    self.each_line do |line|
      if (line =~ /^\s*\S/)
        non_whitespace_column = $&.length - 1
        break
      end
    end
    
    # iterate through each line, chopping off leftmost whitespace columns and add back the desired whitespace margin
    self.each_line do |line|
      columns = []
      margin.times{columns << ' '}
      # handle special case of line being narrower than width to be lopped off
      if (non_whitespace_column < line.length)
        new_lines << "#{columns.join}#{line[non_whitespace_column..-1]}"
      else
        new_lines << "\n"
      end
    end
    
    return new_lines.join
  end
end

class Plugin
  attr_reader :name, :environment
  attr_accessor :plugin_objects

  def initialize(system_objects, name)
    @environment = []
    @ceedling = system_objects
    @name = name
    self.setup
  end

  def setup; end
  
  def summary; end

end
