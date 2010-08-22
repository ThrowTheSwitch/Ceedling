require File.dirname(__FILE__) + '/../unit_test_helper'
require 'generator'


class GeneratorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :preprocessinator, :cmock_factory, :generator_test_runner, :generator_test_results, :test_includes_extractor, :tool_executor, :file_finder, :file_path_utils, :streaminator, :plugin_manager, :file_wrapper)
    create_mocks(:cmock, :file)
    @generator = Generator.new(objects)
  end

  def teardown
  end

  ################### includes preprocessing ####################  

  should "generate shallow includes list file" do
    @preprocessinator.expects.preprocess_shallow_includes('project/tests/test_file.c')
    
    @generator.generate_shallow_includes_list('project/tests/test_file.c')
  end

  ################### file preprocessing ####################  

  should "generate preprocessed version of file" do
    @streaminator.expects.stdout_puts("Preprocessing test_icle.c...", Verbosity::NORMAL)
    
    @preprocessinator.expects.preprocess_file('project/tests/test_icle.c')
    
    @generator.generate_preprocessed_file('project/tests/test_icle.c')
  end

  ################### auxiliary dependencies ####################  

  should "generate auxiliary dependencies file" do
    @streaminator.expects.stdout_puts("Generating dependencies for file.c...", Verbosity::NORMAL)

    @configurator.expects.tools_dependencies_generator.returns('gcc -depgen')
    @file_path_utils.expects.form_object_filepath('project/files/src/file.c').returns('project/build/file.o')
    
    @tool_executor.expects.build_command_line('gcc -depgen', 'project/files/src/file.c', ['types.h', 'helper.h'], 'project/build/file.o').returns('dep cmd line')
    
    @tool_executor.expects.exec('dep cmd line')
    
    @generator.generate_dependencies_file('project/files/src/file.c', ['types.h', 'helper.h'])
  end

  ################### cmock ####################  
  
  should "manufacture cmock object if not already in existence and verify that cmock gets called" do
    test_source_header1       = 'files/source/mockable1.h'
    test_preprocessed_header1 = 'files/preprocessed/mockable1.h'
    test_source_header2       = 'files/source/mockable2.h'
    test_preprocessed_header2 = 'files/preprocessed/mockable2.h'
    
    # instantiate cmock as it doesn't exist and then call against to create mock
    @configurator.expects.cmock_config_hash.returns({:cmock => []})
    @cmock_factory.expects.manufacture({:cmock => []}).returns(@cmock)
    @preprocessinator.expects.form_file_path(test_source_header1).returns(test_preprocessed_header1)
    @cmock.expects.setup_mocks(test_preprocessed_header1)
    @generator.generate_mock(test_source_header1)

    # don't instantiate cmock as it already exists and then against it to create mock
    @preprocessinator.expects.form_file_path(test_source_header2).returns(test_preprocessed_header2)
    @cmock.expects.setup_mocks(test_preprocessed_header2)
    @generator.generate_mock(test_source_header2)
  end

  ################### test runner ####################  

  should "generate test runner" do
    test_source         = 'tests/test_count_chocula.c'
    preprocessed_source = 'preprocessed/test_count_chocula.c'
    test_runner         = 'build/runners/test_count_chocula_runner.c'
    test_cases          = ['test_how_much_goodness', 'test_chocolatey_milk']
    mock_list           = ['mock_marshmallows.h', 'mock_cereal_bits.h']

    @preprocessinator.expects.form_file_path(test_source).returns(preprocessed_source)
    
    @generator_test_runner.expects.find_test_cases(preprocessed_source).returns(test_cases)
    @test_includes_extractor.expects.lookup_raw_mock_list(preprocessed_source).returns(mock_list)
    
    @streaminator.expects.stdout_puts("Creating test runner for test_count_chocula.c...", Verbosity::NORMAL)
    
    @file_wrapper.expects.open(test_runner, 'w').yields(@file)
    
    @generator_test_runner.expects.create_header(@file, mock_list)
    @generator_test_runner.expects.create_externs(@file, test_cases)
    @generator_test_runner.expects.create_mock_management(@file, mock_list)
    @generator_test_runner.expects.create_runtest(@file, mock_list, test_cases)
    @generator_test_runner.expects.create_main(@file, 'test_count_chocula.c', test_cases)
        
    @generator.generate_test_runner(test_source, test_runner)
  end

  ################### compilation ####################  

  should "compile object file" do
    tool_config = {:tools_test_compiler => {}}

    @streaminator.expects.stdout_puts("Compiling compile_me.c...", Verbosity::NORMAL)
    
    @configurator.expects.tools_test_compiler.returns(tool_config)
    
    @tool_executor.expects.build_command_line(tool_config, 'files/modules/compile_me.c', 'build/out/compile_me.o').returns('compiler.exe input output')
    @tool_executor.expects.exec('compiler.exe input output').returns('ignore this')

    @generator.generate_object_file('files/modules/compile_me.c', 'build/out/compile_me.o')
  end

  ################### linking ####################  

  should "link executable file" do
    tool_config = {:tools_test_linker => {}}

    @streaminator.expects.stdout_puts("Linking link_me.out...", Verbosity::NORMAL)
    
    @configurator.expects.tools_test_linker.returns(tool_config)
    
    @tool_executor.expects.build_command_line(tool_config, ['build/out/compile_me.o', 'build/out/compile_me_too.o'], 'build/out/link_me.out').returns('linker.exe input output')
    @tool_executor.expects.exec('linker.exe input output').returns('ignore this')

    @generator.generate_executable_file(['build/out/compile_me.o', 'build/out/compile_me_too.o'], 'build/out/link_me.out')
  end

  ################### test execution ####################  

  should "execute test and process results to file" do
    tool_config = {:tools_test_runner => {}}
    arg_hash = {:executable => 'build/out/test.out', :result => 'build/results/test.pass'}

    @plugin_manager.expects.pre_test_execute(arg_hash)
    
    @streaminator.expects.stdout_puts("Running test.out...", Verbosity::NORMAL)
    
    @configurator.expects.tools_test_fixture.returns(tool_config)
    
    @tool_executor.expects.build_command_line(tool_config, arg_hash[:executable]).returns('simulator.exe test.out')
    @tool_executor.expects.exec('simulator.exe test.out').returns('test results')

    @file_finder.expects.find_test_from_file_path(arg_hash[:executable]).returns('tests/test.c')
    
    @generator_test_results.expects.process_and_write_results('test results', arg_hash[:result], 'tests/test.c')

    @plugin_manager.expects.post_test_execute(arg_hash)

    @generator.generate_test_results(arg_hash[:executable], arg_hash[:result])    
  end

  should "raise if test execution yields nil results" do
    tool_config = {:tools_test_runner => {}}
    arg_hash = {:executable => 'build/out/test.out', :result => 'build/results/test.pass'}

    @plugin_manager.expects.pre_test_execute(arg_hash)

    @streaminator.expects.stdout_puts("Running test.out...", Verbosity::NORMAL)
    
    @configurator.expects.tools_test_fixture.returns(tool_config)
    
    @tool_executor.expects.build_command_line(tool_config, arg_hash[:executable]).returns('simulator.exe test.out')
    @tool_executor.expects.exec('simulator.exe test.out').returns(nil)

    @streaminator.expects.stderr_puts("ERROR: Test executable \"test.out\" did not produce any results.", Verbosity::ERRORS)

    assert_raise(RuntimeError) { @generator.generate_test_results(arg_hash[:executable], arg_hash[:result]) }
  end

  should "raise if test execution yields a string with no parseable results" do
    tool_config = {:tools_test_runner => {}}
    arg_hash = {:executable => 'build/out/test.out', :result => 'build/results/test.pass'}

    @plugin_manager.expects.pre_test_execute(arg_hash)

    @streaminator.expects.stdout_puts("Running test.out...", Verbosity::NORMAL)
    
    @configurator.expects.tools_test_fixture.returns(tool_config)
    
    @tool_executor.expects.build_command_line(tool_config, arg_hash[:executable]).returns('simulator.exe test.out')
    @tool_executor.expects.exec('simulator.exe test.out').returns('')

    @streaminator.expects.stderr_puts("ERROR: Test executable \"test.out\" did not produce any results.", Verbosity::ERRORS)

    assert_raise(RuntimeError) { @generator.generate_test_results('build/out/test.out', 'build/results/test.pass') }
  end

end
