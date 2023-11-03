
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

  # Preprocessing (before / after each and every header file preprocessing operation before mocking)
  def pre_mock_preprocess(arg_hash); end
  def post_mock_preprocess(arg_hash); end

  # Preprocessing (before / after each and every test preprocessing operation before runner generation)
  def pre_test_preprocess(arg_hash); end
  def post_test_preprocess(arg_hash); end

  # Mock generation (before / after each and every mock)
  def pre_mock_generate(arg_hash); end
  def post_mock_generate(arg_hash); end

  # Test runner generation (before / after each and every test runner)
  def pre_runner_generate(arg_hash); end
  def post_runner_generate(arg_hash); end

  # Compilation (before / after each and test or source file compilation)
  def pre_compile_execute(arg_hash); end
  def post_compile_execute(arg_hash); end

  # Linking (before / after each and every test executable or release artifact)
  def pre_link_execute(arg_hash); end
  def post_link_execute(arg_hash); end

  # Test fixture execution (before / after each and every test fixture executable)
  def pre_test_fixture_execute(arg_hash); end
  def post_test_fixture_execute(arg_hash); end

  # Test task (before / after each test executable build)
  def pre_test(test); end
  def post_test(test); end

  # Release task (before / after a release build)
  def pre_release; end
  def post_release; end

  # Whole shebang (any use of Ceedling)
  def pre_build; end
  def post_build; end
  
  def summary; end

end
