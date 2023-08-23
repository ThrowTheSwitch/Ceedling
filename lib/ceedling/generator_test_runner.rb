
class GeneratorTestRunner

  constructor :configurator, :file_path_utils, :file_wrapper

  def find_test_cases(test_filepath:, input_filepath:)

    #Pull in Unity's Test Runner Generator
    require 'generate_test_runner.rb'
    @test_runner_generator ||= UnityTestRunnerGenerator.new( @configurator.get_runner_config )

    if (@configurator.project_use_test_preprocessor)
      #actually look for the tests using Unity's test runner generator
      contents = @file_wrapper.read(input_filepath)
      tests_and_line_numbers = @test_runner_generator.find_tests(contents)
      @test_runner_generator.find_setup_and_teardown(contents)

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
      #Just look for the tests using Unity's test runner generator
      contents = @file_wrapper.read(test_filepath)
      tests_and_line_numbers = @test_runner_generator.find_tests(contents)
      @test_runner_generator.find_setup_and_teardown(contents)
    end

    return tests_and_line_numbers
  end

  def generate(module_name, runner_filepath, test_cases, mock_list, test_file_includes=[])
    require 'generate_test_runner.rb'

    header_extension = @configurator.extension_header

    # Actually build the test runner using Unity's test runner generator.
    # (There is no need to use preprocessor here because we've already looked up test cases and are passing them in here.)
    @test_runner_generator ||= UnityTestRunnerGenerator.new( @configurator.get_runner_config )
    @test_runner_generator.generate( module_name,
                                     runner_filepath,
                                     test_cases,
                                     mock_list.map{ |mock| mock + header_extension },
                                     test_file_includes.map{|f| File.basename(f,'.*') + header_extension})
  end
end
