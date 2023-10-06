require 'generate_test_runner.rb' # Unity's test runner generator

class GeneratorTestRunner

  constructor :configurator, :file_path_utils, :file_wrapper

  def manufacture()
    return UnityTestRunnerGenerator.new( @configurator.get_runner_config )
  end

  def find_test_cases(generator:, test_filepath:, input_filepath:)

    if (@configurator.project_use_test_preprocessor)
      #actually look for the tests using Unity's test runner generator
      contents = @file_wrapper.read(input_filepath)
      tests_and_line_numbers = generator.find_tests(contents)
      generator.find_setup_and_teardown(contents)

      #look up the line numbers in the original file
      source_lines = @file_wrapper.read(test_filepath).split("\n")
      source_index = 0;
      tests_and_line_numbers.size.times do |i|
        source_lines[source_index..-1].each_with_index do |line, index|
          if (line =~ /#{tests_and_line_numbers[i][:test]}/)
            source_index += index
            tests_and_line_numbers[i][:line_number] = source_index + 1
            break
          end
        end
      end
    else
      # Just look for the tests using Unity's test runner generator
      contents = @file_wrapper.read(test_filepath)
      tests_and_line_numbers = generator.find_tests(contents)
      generator.find_setup_and_teardown(contents)
    end

    return tests_and_line_numbers
  end

  def generate(generator:, module_name:, runner_filepath:, test_cases:, mock_list:, test_file_includes:[])
    header_extension = @configurator.extension_header

    # Actually build the test runner using Unity's test runner generator.
    # (There is no need to use preprocessor here because we've already looked up test cases and are passing them in here.)
    generator.generate(
      module_name,
      runner_filepath,
      test_cases,
      mock_list.map{ |mock| mock + header_extension },
      test_file_includes.map{|f| File.basename(f,'.*') + header_extension}
      )
  end
end
