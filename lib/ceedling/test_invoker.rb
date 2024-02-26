require 'ceedling/constants'
require 'fileutils'

class TestInvoker

  attr_reader :sources, :tests, :mocks

  constructor :application,
              :configurator,
              :test_invoker_helper,
              :plugin_manager,
              :streaminator,
              :build_batchinator,
              :preprocessinator,
              :task_invoker,
              :generator,
              :test_context_extractor,
              :file_path_utils,
              :file_wrapper,
              :verbosinator

  def setup
    # Master data structure for all test activities
    @testables = {}

    # For thread-safe operations on @testables
    @lock = Mutex.new

    # Aliases for brevity in code that follows
    @helper = @test_invoker_helper
    @batchinator = @build_batchinator
  end

  def setup_and_invoke(tests:, context:TEST_SYM, options:{})
    # Wrap everything in an exception handler
    begin
      # Begin fleshing out the testables data structure
      @batchinator.build_step("Preparing Build Paths", heading: false) do
        results_path = File.join( @configurator.project_build_root, context.to_s, 'results' )

        @batchinator.exec(workload: :compile, things: tests) do |filepath|
          filepath = filepath.to_s
          key = testable_symbolize(filepath)
          name = key.to_s
          build_path = File.join( @configurator.project_build_root, context.to_s, 'out', name )
          mocks_path = File.join( @configurator.cmock_mock_path, name )
          preprocess_includes_path = File.join( @configurator.project_test_preprocess_includes_path, name )
          preprocess_files_path    = File.join( @configurator.project_test_preprocess_files_path, name )

          @lock.synchronize do
            @testables[key] = {
              :filepath => filepath,
              :name => name,
              :paths => {}
            }

            paths = @testables[key][:paths]
            paths[:build] = build_path
            paths[:results] = results_path
            paths[:mocks] = mocks_path if @configurator.project_use_mocks
            if @configurator.project_use_test_preprocessor
              paths[:preprocess_incudes] = preprocess_includes_path
              paths[:preprocess_files] = preprocess_files_path
            end
          end

          @testables[key][:paths].each {|_, path| @file_wrapper.mkdir(path) }
        end

        # Remove any left over test results from previous runs
        @helper.clean_test_results( results_path, @testables.map{ |_, t| t[:name] } )
      end

      # Collect in-test build directives, etc. from test files
      @batchinator.build_step("Extracting Build Directive Macros") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          @preprocessinator.extract_test_build_directives( filepath:details[:filepath] )
        end

        # Validate test build directive paths via TEST_INCLUDE_PATH() & augment header file collection from the same
        @helper.process_project_include_paths()

        # Validate test build directive source file entries via TEST_SOURCE_FILE()
        @testables.each do |_, details|
          @helper.validate_build_directive_source_files( test:details[:name], filepath:details[:filepath] )
        end
      end

      # Fill out testables data structure with build context
      @batchinator.build_step("Ingesting Test Configurations") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]

          search_paths       = @helper.search_paths( filepath, details[:name] )
          compile_flags      = @helper.flags( context:context, operation:OPERATION_COMPILE_SYM, filepath:filepath )
          assembler_flags    = @helper.flags( context:context, operation:OPERATION_ASSEMBLE_SYM, filepath:filepath )
          link_flags         = @helper.flags( context:context, operation:OPERATION_LINK_SYM, filepath:filepath )
          compile_defines    = @helper.compile_defines( context:context, filepath:filepath )
          preprocess_defines = @helper.preprocess_defines( test_defines: compile_defines, filepath:filepath )

          @streaminator.stdout_puts( "Collecting search paths, flags, and defines for #{File.basename(filepath)}...", Verbosity::NORMAL)

          @lock.synchronize do
            details[:search_paths] = search_paths
            details[:compile_flags] = compile_flags
            details[:assembler_flags] = assembler_flags
            details[:link_flags] = link_flags
            details[:compile_defines] = compile_defines
            details[:preprocess_defines] = preprocess_defines
          end
        end
      end

      # Collect include statements & mocks from test files
      @batchinator.build_step("Collecting Testing Context") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          arg_hash = {
            filepath:      details[:filepath],
            test:          details[:name],
            flags:         details[:compile_flags],
            include_paths: details[:search_paths],
            defines:       details[:preprocess_defines]
          }

          @preprocessinator.extract_testing_context(**arg_hash)
        end
      end

      # Determine Runners & Mocks For All Tests
      @batchinator.build_step("Determining Files to be Generated", heading: false) do
        @batchinator.exec(workload: :compile, things: @testables) do |test, details|
          runner_filepath = @file_path_utils.form_runner_filepath_from_test( details[:filepath] )
          
          mocks = {}
          mocks_list = @configurator.project_use_mocks ? @test_context_extractor.lookup_raw_mock_list( details[:filepath] ) : []
          mocks_list.each do |name|
            source = @helper.find_header_input_for_mock_file( name, details[:search_paths] )
            preprocessed_input = @file_path_utils.form_preprocessed_file_filepath( source, details[:name] )
            mocks[name.to_sym] = {
              :name => name,
              :source => source,
              :input => (@configurator.project_use_test_preprocessor ? preprocessed_input : source)
            }
          end

          @lock.synchronize do
            details[:runner] = {
              :output_filepath => runner_filepath,
              :input_filepath => details[:filepath]  # Default of the test file
            }
            details[:mocks] = mocks
            details[:mock_list] = mocks_list

            # Trigger pre_test plugin hook after having assembled all testing context
            @plugin_manager.pre_test( details[:filepath] )
          end
        end
      end

      # Create inverted/flattened mock lookup list to take advantage of threading
      # (Iterating each testable and mock list instead would limits the number of simultaneous mocking threads)
      mocks = []
      if @configurator.project_use_mocks
        @testables.each do |_, details|
          details[:mocks].each do |name, elems|
            mocks << {:name => name, :details => elems, :testable => details}
          end
        end
      end

      # Preprocess Header Files
      @batchinator.build_step("Preprocessing for Mocks") {
        @batchinator.exec(workload: :compile, things: mocks) do |mock|
          details = mock[:details]
          testable = mock[:testable]

          arg_hash = {
            filepath:      details[:source],
            test:          testable[:name],
            flags:         testable[:compile_flags],
            include_paths: testable[:search_paths],
            defines:       testable[:preprocess_defines]
          }

          @preprocessinator.preprocess_mockable_header_file(**arg_hash)
        end
      } if @configurator.project_use_mocks and @configurator.project_use_test_preprocessor

      # Generate mocks for all tests
      @batchinator.build_step("Mocking") {
        @batchinator.exec(workload: :compile, things: mocks) do |mock| 
          details = mock[:details]
          testable = mock[:testable]

          arg_hash = {
            context:        TEST_SYM,
            mock:           mock[:name],
            test:           testable[:name],
            input_filepath: details[:input],
            output_path:    testable[:paths][:mocks]
          }

          @generator.generate_mock(**arg_hash)
        end
      } if @configurator.project_use_mocks

      # Preprocess test files
      @batchinator.build_step("Preprocessing for Test Runners") {
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|

          arg_hash = {
            filepath:      details[:filepath],
            test:          details[:name],
            flags:         details[:compile_flags],
            include_paths: details[:search_paths],
            defines:       details[:preprocess_defines]
          }

          filepath = @preprocessinator.preprocess_test_file(**arg_hash)

          # Replace default input with preprocessed fle
          @lock.synchronize { details[:runner][:input_filepath] = filepath }
        end
      } if @configurator.project_use_test_preprocessor

      # Build runners for all tests
      @batchinator.build_step("Test Runners") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          arg_hash = {
            context:         TEST_SYM,
            mock_list:       details[:mock_list],
            test_filepath:   details[:filepath],
            input_filepath:  details[:runner][:input_filepath],
            runner_filepath: details[:runner][:output_filepath]            
          }

          @generator.generate_test_runner(**arg_hash)
        end
      end

      # Determine objects required for each test
      @batchinator.build_step("Determining Artifacts to Be Built", heading: false) do
        @batchinator.exec(workload: :compile, things: @testables) do |test, details|
          # Source files referenced by conventions or specified by build directives in a test file
          test_sources       = @test_invoker_helper.extract_sources( details[:filepath] )
          test_core          = test_sources + details[:mock_list]

          # When we have a mock and an include for the same file, the mock wins
          test_core.delete_if do |v| 
            mock_of_this_file = "#{@configurator.cmock_mock_prefix}#{File.basename(v,'.*')}"
            details[:mock_list].include?(mock_of_this_file)
          end
          
          # CMock + Unity + CException
          test_frameworks    = @helper.collect_test_framework_sources
          
          # Extra suport source files (e.g. microcontroller startup code needed by simulator)
          test_support       = @configurator.collection_all_support

          compilations       =  []
          compilations       << details[:filepath]
          compilations       += test_core
          compilations       << details[:runner][:output_filepath]
          compilations       += test_frameworks
          compilations       += test_support
          compilations.uniq!

          test_objects       = @file_path_utils.form_test_build_objects_filelist( details[:paths][:build], compilations )

          test_executable    = @file_path_utils.form_test_executable_filepath( details[:paths][:build], details[:filepath] )
          test_pass          = @file_path_utils.form_pass_results_filepath( details[:paths][:results], details[:filepath] )
          test_fail          = @file_path_utils.form_fail_results_filepath( details[:paths][:results], details[:filepath] )

          # Identify all the objects shall not be linked and then remove them from objects list.
          test_no_link_objects = 
            @file_path_utils.form_test_build_objects_filelist(
              details[:paths][:build],
              @helper.fetch_shallow_source_includes( details[:filepath] ))
          
          test_objects = test_objects.uniq - test_no_link_objects

          @lock.synchronize do
            details[:sources]         = test_sources
            details[:frameworks]      = test_frameworks
            details[:core]            = test_core
            details[:objects]         = test_objects
            details[:executable]      = test_executable
            details[:no_link_objects] = test_no_link_objects
            details[:results_pass]    = test_pass
            details[:results_fail]    = test_fail
          end
        end
      end

      # Build All Test objects
      @batchinator.build_step("Building Objects") do
        # FYI: Temporarily removed direct object generation to allow rake invoke() to execute custom compilations (plugins, special cases)
        # @test_invoker_helper.generate_objects_now(object_list, options)
        @testables.each do |_, details|
          @task_invoker.invoke_test_objects(test: details[:name], objects:details[:objects])
        end
      end

      # Create test binary
      @batchinator.build_step("Building Test Executables") do
        lib_args = @helper.convert_libraries_to_arguments()
        lib_paths = @helper.get_library_paths_to_arguments()
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          arg_hash = {
            context:    context,
            build_path: details[:paths][:build],
            executable: details[:executable],
            objects:    details[:objects],
            flags:      details[:link_flags],
            lib_args:   lib_args,
            lib_paths:  lib_paths,
            options:    options            
          }

          @test_invoker_helper.generate_executable_now(**arg_hash)
        end
      end

      # Execute Final Tests
      @batchinator.build_step("Executing") {
        @batchinator.exec(workload: :test, things: @testables) do |_, details|
          begin
            arg_hash = {
              context:        context,
              test_name:      details[:name],
              test_filepath:  details[:filepath],
              executable:     details[:executable],
              result:         details[:results_pass],
              options:        options              
            }

            @test_invoker_helper.run_fixture_now(**arg_hash)

          # Handle exceptions so we can ensure post_test() is called.
          # A lone `ensure` includes an implicit rescuing of StandardError 
          # with the exception continuing up the call trace.
          ensure
            @plugin_manager.post_test( details[:filepath] )
          end
        end
      } unless options[:build_only]

    # Handle application-level exceptions.
    # StandardError is the parent class of all application-level exceptions.
    # Runtime errors (parent is Exception) continue on up to be caught by Ruby itself.
    rescue StandardError => e
      @application.register_build_failure
      @streaminator.stderr_puts("#{e.class} ==> #{e.message}", Verbosity::ERRORS)

      # Debug backtrace
      @streaminator.stderr_puts("Backtrace ==>", Verbosity::DEBUG)
      if @verbosinator.should_output?(Verbosity::DEBUG)
        $stderr.puts(e.backtrace) # Formats properly when directly passed to puts()
      end
    end
  end

  def each_test_with_sources
    @testables.each do |test, details|
      yield(test.to_s, lookup_sources(test:test))
    end
  end

  def lookup_sources(test:)
    _test = test.is_a?(Symbol) ? test : test.to_sym
    return (@testables[_test])[:sources]
  end

  def compile_test_component(tool:, context:TEST_SYM, test:, source:, object:, msg:nil)
    testable = @testables[test]
    filepath = testable[:filepath]
    defines = testable[:compile_defines]

    # Tailor search path--remove duplicates and reduce list to only those needed by vendor / support file compilation
    search_paths = @helper.tailor_search_paths(search_paths:testable[:search_paths], filepath:source)

    # C files (user-configured extension or core framework file extensions)
    if @file_wrapper.extname(source) != @configurator.extension_assembly
      flags = testable[:compile_flags]

      arg_hash = {
        tool:         tool,
        module_name:  test,
        context:      context,
        source:       source,
        object:       object,
        search_paths: search_paths,
        flags:        flags,
        defines:      defines,
        list:         @file_path_utils.form_test_build_list_filepath( object ),
        dependencies: @file_path_utils.form_test_dependencies_filepath( object ),
        msg:          msg
      }

      @generator.generate_object_file_c(**arg_hash)

    # Assembly files
    elsif @configurator.test_build_use_assembly
      flags = testable[:assembler_flags]

      arg_hash = {
        tool:         tool,
        module_name:  test,
        context:      context,
        source:       source,
        object:       object,
        search_paths: search_paths,
        flags:        flags,
        defines:      defines, # Generally ignored by assemblers
        list:         @file_path_utils.form_test_build_list_filepath( object ),
        dependencies: @file_path_utils.form_test_dependencies_filepath( object ),
        msg:          msg
      }

      @generator.generate_object_file_asm(**arg_hash)
    end
  end

  private

  def testable_symbolize(filepath)
    return (File.basename( filepath ).ext('')).to_sym
  end

end
