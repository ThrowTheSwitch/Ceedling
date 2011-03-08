
class String
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
  attr_reader :name

  def initialize(system_objects, name)
    @ceedling = system_objects
    @name = name
    self.setup
  end

  def setup; end

  def pre_build; end

  def pre_mock_execute(arg_hash); end
  def post_mock_execute(arg_hash); end

  def pre_runner_execute(arg_hash); end
  def post_runner_execute(arg_hash); end

  def pre_compile_execute(arg_hash); end
  def post_compile_execute(arg_hash); end

  def pre_link_execute(arg_hash); end
  def post_link_execute(arg_hash); end

  def pre_test_execute(arg_hash); end
  def post_test_execute(arg_hash); end

  def post_build; end
  
  def summary; end

end
