
class GeneratorTestRunner

  constructor :configurator, :file_path_utils, :file_wrapper

  def find_test_cases(test_file)
    require 'generate_test_runner.rb'
    @test_runner_generator ||= UnityTestRunnerGenerator.new( @configurator.get_runner_config )
    return @test_runner_generator.find_tests(@file_wrapper.read(test_file))
  end

  def generate(module_name, runner_filepath, test_cases, mock_list, test_file_includes=[])
    require 'generate_test_runner.rb'
    @test_runner_generator ||= UnityTestRunnerGenerator.new( @configurator.get_runner_config )
    @test_runner_generator.generate( module_name,
                                     runner_filepath,
                                     test_cases,
                                     mock_list,
                                     test_file_includes)
  end
end
