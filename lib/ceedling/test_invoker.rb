# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes'
require 'fileutils'

class TestInvoker

  attr_reader :sources, :tests, :mocks

  constructor :application,
              :configurator,
              :test_invoker_helper,
              :plugin_manager,
              :reportinator,
              :loginator,
              :batchinator,
              :preprocessinator,
              :task_invoker,
              :partializer,
              :generator,
              :test_context_extractor,
              :file_path_utils,
              :file_wrapper,
              :file_finder,
              :verbosinator

  def setup
    # Master data structure for all test activities
    @testables = {}

    # For thread-safe operations on @testables
    @lock = Mutex.new

    # Aliases for brevity in code that follows
    @helper = @test_invoker_helper
    @context_extractor = @test_context_extractor
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
          partials_path = File.join( @configurator.project_test_partials_path, name )

          # Create build, results, and mock/partial paths

          preprocess_includes_path = File.join( @configurator.project_test_preprocess_includes_path, name )
          preprocess_files_path    = File.join( @configurator.project_test_preprocess_files_path, name )

          @lock.synchronize do
            @testables[key] = {
              :filepath => filepath,
              :name => name,
              :preprocess => {},
              :paths => {}
            }
          end

          paths = @testables[key][:paths]
          paths[:build] = build_path
          paths[:results] = results_path
          paths[:mocks] = mocks_path if @configurator.project_use_mocks
          paths[:partials] = partials_path if @configurator.project_use_partials
          if @configurator.project_use_test_preprocessor != :none
            # Temporary list of bare includes (not user/system specialized)
            @testables[key][:preprocess][:includes] = []
            @testables[key][:preprocess][:directives_only] = {
              :filepath => nil
            }

            paths[:preprocess_incudes] = preprocess_includes_path
            paths[:preprocess_files] = preprocess_files_path
            paths[:preprocess_files_full_expansion] = File.join( preprocess_files_path, PREPROCESS_FULL_EXPANSION_DIR )
            paths[:preprocess_files_directives_only] = File.join( preprocess_files_path, PREPROCESS_DIRECTIVES_ONLY_DIR )
          end

          @testables[key][:paths].each {|_, path| @file_wrapper.mkdir( path ) }
        end

        # Remove any left over test results from previous runs
        @helper.clean_test_results( results_path, @testables.map{ |_, t| t[:name] } )
      end

      # Collect in-test build directives, #include statements, and test cases from test files.
      # (Actions depend on preprocessing configuration)
      @batchinator.build_step("Collecting Essential Test Context") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]

          # Always extract includes via regex.
          #  - In non-preprocessing builds, we only use this.
          #  - With fallback options if certain kinds of preprocessing are unavailable, use the regex includes instead.
          contexts = [:includes]

          if @configurator.project_use_test_preprocessor_tests
            # Extracting other context will happen in later steps after preprocessing.
            contexts << :build_directive_include_paths

            msg = @reportinator.generate_progress( "Parsing #{File.basename(filepath)} for include path build directive macros" )
            @loginator.log( msg )
          else
            # Extract context without preprocessing.
            contexts << :build_directive_include_paths
            contexts << :build_directive_source_files
            contexts << :test_runner_details

            msg = @reportinator.generate_progress( "Parsing #{File.basename(filepath)} for build directive macros, #includes, and test case names" )
            @loginator.log( msg )
          end

          if @configurator.project_use_partials
            contexts << :partials_configuration

            msg = @reportinator.generate_progress( "Parsing #{File.basename(filepath)} for partials directive macros" )
            @loginator.log( msg )
          end

          # Collect test context using text scanning (no preprocessing involved here)
          @file_wrapper.open( filepath, 'r' ) do |input|
            @context_extractor.collect_simple_context( filepath, input, *contexts )
          end

        end

        # Validate paths via TEST_INCLUDE_PATH() & augment header file collection from the same
        @helper.process_project_include_paths()
      end

      # Fill out testables data structure with build context
      @batchinator.build_step("Ingesting Test Configurations") do
        framework_defines  = @helper.framework_defines()
        runner_defines     = @helper.runner_defines()

        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]

          search_paths       = @helper.search_paths( filepath, details[:paths] )

          compile_flags      = @helper.flags( context:context, operation:OPERATION_COMPILE_SYM, filepath:filepath )
          preprocess_flags   = @helper.preprocess_flags( context:context, compile_flags:compile_flags, filepath:filepath )
          assembler_flags    = @helper.flags( context:context, operation:OPERATION_ASSEMBLE_SYM, filepath:filepath )
          link_flags         = @helper.flags( context:context, operation:OPERATION_LINK_SYM, filepath:filepath )

          compile_defines    = @helper.compile_defines( context:context, filepath:filepath )
          preprocess_defines = @helper.preprocess_defines( test_defines: compile_defines, filepath:filepath )

          msg = @reportinator.generate_module_progress(
            operation: 'Collecting search paths, flags, and defines',
            module_name: details[:name],
            filename: File.basename( details[:filepath] )
          )
          @loginator.log( msg )

          @lock.synchronize do
            details[:search_paths] = search_paths
            details[:preprocess_flags] = preprocess_flags
            details[:compile_flags] = compile_flags
            details[:assembler_flags] = assembler_flags
            details[:link_flags] = link_flags
            details[:compile_defines] = compile_defines + framework_defines + runner_defines
            details[:preprocess_defines] = preprocess_defines + framework_defines
          end
        end
      end

      # Collect includes from test files
      @batchinator.build_step("Collecting More Test Context") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]
          name = details[:name]

          # Skip running the preprocessor if we have good, cachced includes
          next if @preprocessinator.cached_includes_list?( test: name, filepath: filepath )

          arg_hash = {
            test:          details[:name],
            filepath:      details[:filepath],
            # For user includes preprocessing, we need at least one search path
            search_paths:  [@configurator.project_build_vendor_ceedling_path],
            flags:         details[:preprocess_flags],
            defines:       details[:preprocess_defines]
          }

          msg = @reportinator.generate_module_progress(
            operation: 'Extracting bare #includes for',
            module_name: name,
            filename: File.basename( filepath )
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )

          # Extract user includes
          includes = @preprocessinator.preprocess_bare_includes( **arg_hash )
          
          # Temporarily store includes for future use
          details[:preprocess][:includes] = includes
          
          # Create blank mocks and partials to keep preprocessing happy before we generate these files
          @helper.generate_test_includes_standins( name, includes )
        end

        # Generate directive-only preprocessor output only after stand-ins are present
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]
          name = details[:name]

          arg_hash = {
            filepath:      details[:filepath],
            test:          details[:name],
            flags:         details[:preprocess_flags],
            include_paths: details[:search_paths],
            vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
            defines:       details[:preprocess_defines]
          }

          msg = @reportinator.generate_module_progress(
            operation: 'Preprocessing test files for follow-on details extraction steps',
            module_name: name,
            filename: File.basename( filepath )
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )

          # Generate directive-only preprocessor output for test file to be used multiple times hereafter
          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )
          details[:preprocess][:directives_only][:filepath] = _filepath
        end

        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]
          name = details[:name]

          # Skip running the preprocessor if we have good, cachced includes
          cached, includes = @preprocessinator.load_includes_list( test: name, filepath: filepath )
          if cached
            header = "Loaded #include list for #{filepath}"
            @loginator.log_list( includes, header, Verbosity::OBNOXIOUS )
            @context_extractor.ingest_includes( filepath, includes )
            next
          end

          # Skip using preprocessed input if directive-only preprocessor output is not available
          # The includes we already extracted with regex are all that we have
          if !@preprocessinator.directives_only_available?
            # We already have all the includes we will extract via regex
            msg = @reportinator.generate_module_progress(
              operation: 'Using fallback text-only system includes extraction',
              module_name: name,
              filename: File.basename( filepath )
            )
            @loginator.log( msg, Verbosity::OBNOXIOUS )
            next
          end

          directive_only_filepath = details[:preprocess][:directives_only][:filepath]
          system_includes = []

          if !directive_only_filepath.nil?
            # If directive-only preprocessor output is available, extract system includes from it
            arg_hash = {
              filepath:                 filepath,
              directives_only_filepath: directive_only_filepath
            }

            msg = @reportinator.generate_module_progress(
              operation: 'Extracting system #includes for',
              module_name: name,
              filename: File.basename( filepath )
            )
            @loginator.log( msg )

            system_includes = @preprocessinator.preprocess_system_includes( **arg_hash )
          else
            # Otherwise, grab the system includes we already have via regex
            system_includes = Includes.system(
              @context_extractor.lookup_full_header_includes_list( filepath )
            )
          end

          # Get existing list of bare includes
          bare_includes = details[:preprocess][:includes]

          # Reconcile includes with overlapping information from imperfect extraction
          all_includes = Includes.reconcile( bare: bare_includes, system: system_includes )

          header = "Extracted #include list from #{filepath}"
          @loginator.log_list( all_includes, header, Verbosity::OBNOXIOUS )

          # Update full list of includes (performs santization)
          @context_extractor.ingest_includes( filepath, all_includes )

          @preprocessinator.store_includes_list(
            test: name,
            filepath: filepath,
            includes: all_includes
          )
        end
      end if @configurator.project_use_test_preprocessor_tests

      # Determine Runners, Mocks & Partials for All Tests
      @batchinator.build_step("Determining Files to Be Generated", heading: false) do
        @batchinator.exec(workload: :compile, things: @testables) do |test, details|
          # Runners
          runner_filepath = @file_path_utils.form_runner_filepath_from_test( details[:filepath] )
          
          # Mocks
          mocks = {}
          mocks_list = @configurator.project_use_mocks ? @context_extractor.lookup_raw_mock_list( details[:filepath] ) : []
          mocks_list.each do |name|
            source = nil
            input = nil

            # Handle mock partial vs. (optionally preprocessed) project header
            if @helper.is_mock_partial?( name )
              source = @helper.gnerate_header_input_for_mock_partial( name, details[:name] )
              input = source
            else
              source = @helper.find_header_input_for_mock( name )
              preprocessed_input = @file_path_utils.form_preprocessed_file_filepath( source, details[:name] )
              input = (@configurator.project_use_test_preprocessor_mocks ? preprocessed_input : source)
            end

            mocks[name.to_sym] = {
              :name => name,
              :source => source,
              :input => input
            }
          end

          # Partials
          partials_configs = {}
          if @configurator.project_use_partials
            partials_configs = @helper.assemble_partials_config( filepath: details[:filepath] )
          end

          # Assemble results within safety of mutex
          @lock.synchronize do
            details[:runner] = {
              :output_filepath => runner_filepath,
              :input_filepath => details[:filepath]  # Default of the test file
            }
            details[:mocks] = mocks
            details[:mock_list] = mocks_list
            details[:partials] = {
              :configs => partials_configs,
              :compilations => []
            }

            # Trigger pre_test plugin hook after having assembled all testing context
            @plugin_manager.pre_test( details[:filepath] )
          end
        end
      end

      # Create inverted/flattened partials header & source files lookup list to take advantage of parallel preprocessing
      # (Iterating each testable and partials list instead would limit the number of simultaneous preprocessing threads)
      partials_headers = []
      partials_sources = []
      if @configurator.project_use_partials
        @testables.each do |_, details|
          details[:partials][:configs].each do |_, config|
            partials_headers << {
              :config => config.header,
              :testable => details,
              :directives_only_filepath => nil
            } if config.header.filepath

            partials_sources << {
              :config => config.source,
              :testable => details,
              :directives_only_filepath => nil
            } if config.source.filepath
          end
        end
      end

      # Preprocess Header Files
      @batchinator.build_step("Preprocessing Header Files for Partials") {
        # Generate directive-only preprocessor output
        @batchinator.exec(workload: :compile, things: partials_headers) do |details|
          config = details[:config]
          testable = details[:testable]
          name = testable[:name]

          arg_hash = {
            filepath:      config.filepath,
            test:          name,
            flags:         testable[:preprocess_flags],
            include_paths: testable[:search_paths],
            vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
            defines:       testable[:preprocess_defines]
          }

          msg = @reportinator.generate_module_progress(
            operation: 'Preprocessing header file for follow-on Partials details extraction steps',
            module_name: name,
            filename: File.basename( config.filepath )
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )

          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )
          details[:directives_only_filepath] = _filepath

          # Break-glass just in case (should never happen given earlier steps)
          break if _filepath.nil?
        end if @preprocessinator.directives_only_available?

        # Preprocess and assemble header files
        @batchinator.exec(workload: :compile, things: partials_headers) do |details|
          config = details[:config]
          testable = details[:testable]
          arg_hash = {
            test:                      testable[:name],
            filepath:                  config.filepath,
            directives_only_filepath:  details[:directives_only_filepath],
            fallback:                  !@preprocessinator.directives_only_available?,
            flags:                     testable[:preprocess_flags],
            include_paths:             testable[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   testable[:preprocess_defines]
          }

          config.preprocessed_filepath, config.includes = @preprocessinator.preprocess_partial_header_file( **arg_hash )
        end
      } if @configurator.project_use_partials

      # Preprocess Source Files
      @batchinator.build_step("Preprocessing Source Files for Partials") {
        # Generate directive-only preprocessor output
        @batchinator.exec(workload: :compile, things: partials_sources) do |details|
          config = details[:config]
          testable = details[:testable]
          name = testable[:name]

          arg_hash = {
            filepath:      config.filepath,
            test:          name,
            flags:         testable[:preprocess_flags],
            include_paths: testable[:search_paths],
            vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
            defines:       testable[:preprocess_defines]
          }

          msg = @reportinator.generate_module_progress(
            operation: 'Preprocessing source file for follow-on Partials details extraction steps',
            module_name: name,
            filename: File.basename( config.filepath )
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )

          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )
          details[:directives_only_filepath] = _filepath

          # Break-glass just in case (should never happen given earlier steps)
          break if _filepath.nil?
        end if @preprocessinator.directives_only_available?

        # Preprocess and assemble source files
        @batchinator.exec(workload: :compile, things: partials_sources) do |details|
          config = details[:config]
          testable = details[:testable]
          arg_hash = {
            test:                      testable[:name],
            filepath:                  config.filepath,
            directives_only_filepath:  details[:directives_only_filepath],
            fallback:                  !@preprocessinator.directives_only_available?,
            flags:                     testable[:preprocess_flags],
            include_paths:             testable[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   testable[:preprocess_defines]
          }

          config.preprocessed_filepath, config.includes = @preprocessinator.preprocess_partial_source_file( **arg_hash )
        end
      } if @configurator.project_use_partials
      
      # Generate partials for all tests
      @batchinator.build_step("Partials") {
        # Collect partials for parallel processing
        partials = []
        @testables.each do |_, details|
          next if details[:partials].empty?
          # Create "flattened" partials configuration list for parallel processing
          details[:partials][:configs].each do |_, config|
            partials << {:config => config, :testable => details}
          end
        end

        @batchinator.exec(workload: :compile, things: partials) do |partial| 
          config = partial[:config]
          testable = partial[:testable]

          module_contents = @partializer.extract_module_contents(
            header_filepath: config.header.preprocessed_filepath,
            source_filepath: config.source.preprocessed_filepath
          )

          impl, interface = @partializer.reconstruct_functions(contents: module_contents, types: config.types)

          @partializer.log_extracted_functions(
            test:           testable[:name],
            module_name:    config.module,
            impl:           impl,
            interface:      interface
          )

          source_variables, header_variables = @partializer.reconstruct_variables(variables: module_contents.variables)

          @partializer.log_extracted_variable_decls(
            label:          'Header',
            test:           testable[:name],
            module_name:    config.module,
            decls:          header_variables
          )
          @partializer.log_extracted_variable_decls(
            label:          'Source',
            test:           testable[:name],
            module_name:    config.module,
            decls:          source_variables
          )

          arg_hash = {
            test:             testable[:name],
            name:             config[:module],
            function_defns:   impl,
            header_variables: header_variables,
            source_variables: source_variables,
            header_includes:  @partializer.remap_implementation_header_includes(
                                name: config.module,
                                includes: (config.source.includes + config.header.includes),
                                # All partials configurations to remap includes for partials to be generated
                                partials: testable[:partials][:configs]
                              ),
            source_includes:  @partializer.remap_implementation_source_includes(
                                name: config.module,
                                includes: (config.source.includes + config.header.includes),
                                # All partials configurations to remap includes for partials to be generated
                                partials: testable[:partials][:configs]
                              ),
            input_filepath:   config.source.filepath,
            output_path:      testable[:paths][:partials]
          }

          if !impl.empty?
            @partializer.log_implementation_includes(
              label:          'Source',
              test:           testable[:name],
              module_name:    config.module,
              includes:       arg_hash[:source_includes]
            )
            @partializer.log_implementation_includes(
              label:          'Header',
              test:           testable[:name],
              module_name:    config.module,
              includes:       arg_hash[:header_includes]
            )

            testable[:partials][:compilations] << @generator.generate_partial_implementation(**arg_hash)
          end

          arg_hash = {
            test:           testable[:name],
            name:           config.module,
            declarations:   interface,
            includes:       @partializer.sanitize_includes( 
                              name: config.module,
                              includes: (config.source.includes + config.header.includes)
                            ),
            input_filepath: config.header.filepath,
            output_path:    testable[:paths][:partials]
          }

          if !interface.empty?
            @partializer.log_interface_includes(
              test:           testable[:name],
              module_name:    config.module,
              includes:       arg_hash[:includes]
            )
            @generator.generate_partial_interface(**arg_hash)
          end
        end
      } if @configurator.project_use_partials
      
      # Create inverted/flattened mock lookup list to take advantage of threading
      # (Iterating each testable and mock list instead would limit the number of simultaneous mocking threads)
      mocks = []
      if @configurator.project_use_mocks
        @testables.each do |_, details|
          details[:mocks].each do |name, elems|
            mocks << {
              :name => name,
              :details => elems,
              :testable => details,
              :directives_only_filepath => nil
            }
          end
        end
      end

      # Preprocess header files
      @batchinator.build_step("Preprocessing for Mocks") {
        # Suppress preprocessing for partials headers as they have already been preprocessed
        _mocks = mocks.reject {|mock| mock[:name].to_s.include?( PARTIAL_FILENAME_PREFIX )}

        # Generate directive-only preprocessor output
        @batchinator.exec(workload: :compile, things: _mocks) do |mock|
          details = mock[:details]
          testable = mock[:testable]
          name = testable[:name]
          filepath = details[:source]

          arg_hash = {
            filepath:      filepath,
            test:          name,
            flags:         testable[:preprocess_flags],
            include_paths: testable[:search_paths],
            vendor_paths:  [@configurator.project_build_vendor_ceedling_path],
            defines:       testable[:preprocess_defines]
          }

          msg = @reportinator.generate_module_progress(
            operation: 'Preprocessing mockable header file for follow-on details extraction steps',
            module_name: name,
            filename: File.basename( filepath )
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )

          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )
          mock[:directives_only_filepath] = _filepath

          # Break-glass just in case (should never happen given earlier steps)
          break if _filepath.nil?
        end if @preprocessinator.directives_only_available?

        # Preprocess and assembe header files to be mocked
        @batchinator.exec(workload: :compile, things: _mocks) do |mock|
          details = mock[:details]
          testable = mock[:testable]

          arg_hash = {
            test:                      testable[:name],
            filepath:                  details[:source],
            directives_only_filepath:  mock[:directives_only_filepath],
            fallback:                  !@preprocessinator.directives_only_available?,
            flags:                     testable[:preprocess_flags],
            include_paths:             testable[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   testable[:preprocess_defines]
          }

          @preprocessinator.preprocess_mockable_header_file( **arg_hash )
        end
      } if @configurator.project_use_mocks and @configurator.project_use_test_preprocessor_mocks

      # Generate mocks for all tests
      @batchinator.build_step("Mocking") {
        @batchinator.exec(workload: :compile, things: mocks) do |mock| 
          details = mock[:details]
          testable = mock[:testable]
          # Handle subdirectories for mocks (e.g. `#include "path/mock_file.h`)
          output_subpath = @file_wrapper.dirname( mock[:name].to_s )
          output_path = testable[:paths][:mocks] + (output_subpath.empty? ? '' : "/#{output_subpath}")

          arg_hash = {
            context:        context,
            mock:           mock[:name],
            test:           testable[:name],
            input_filepath: details[:input],
            output_path:    output_path
          }

          @generator.generate_mock(**arg_hash)
        end
      } if @configurator.project_use_mocks

      # Preprocess test files
      @batchinator.build_step("Preprocessing Test Files") {
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          arg_hash = {
            test:                      details[:name],
            filepath:                  details[:filepath],
            directives_only_filepath:  details[:preprocess][:directives_only][:filepath],
            fallback:                  !@preprocessinator.directives_only_available?,
            # We already have the full list of includes for each test file
            includes:                  @context_extractor.lookup_full_header_includes_list( details[:filepath] ),
            flags:                     details[:preprocess_flags],
            include_paths:             details[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   details[:preprocess_defines]
          }

          filepath = @preprocessinator.preprocess_test_file(**arg_hash)

          # Replace default input with preprocessed file
          @lock.synchronize { details[:runner][:input_filepath] = filepath }

          # Collect sources added to test build with TEST_SOURCE_FILE() directive macro
          # TEST_SOURCE_FILE() can be within #ifdef's--this retrieves them
          @file_wrapper.open( filepath, 'r' ) do |input|
            @context_extractor.collect_simple_context( details[:filepath], input, :build_directive_source_files )
          end

          # Validate test build directive source file entries via TEST_SOURCE_FILE()
          @testables.each do |_, details|
            @helper.validate_build_directive_source_files( test:details[:name], filepath:details[:filepath] )
          end
        end
      } if @configurator.project_use_test_preprocessor_tests

      # Collect test case names
      @batchinator.build_step("Collecting More Test Context") {
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|

          msg = @reportinator.generate_module_progress(
            operation: 'Parsing test case names',
            module_name: details[:name],
            filename: File.basename( details[:filepath] )
          ) 
          @loginator.log( msg )

          @context_extractor.collect_test_runner_details( details[:filepath], details[:runner][:input_filepath] )
        end
      } if @configurator.project_use_test_preprocessor_tests

      # Generate runners for all tests
      @batchinator.build_step("Test Runners") do
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          arg_hash = {
            context:         context,
            mock_list:       details[:mock_list],
            includes_list:   @test_context_extractor.lookup_header_includes_list( details[:filepath] ),
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
          test_sources       =  @helper.extract_sources( details[:filepath] )
          test_core          =  test_sources + 
                                @helper.form_mock_filenames( details[:mock_list] ) +
                                details[:partials][:compilations]

          # When we have a mock and an include for the same file, the mock wins
          @helper.remove_mock_original_headers( test_core, details[:mock_list] )
          
          # CMock + Unity + CException
          test_frameworks    = @helper.collect_test_framework_sources( !details[:mock_list].empty? )
          
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

          # Assemble a list of object files from .c files that have been #included in the test file
          test_no_link_objects = 
            @file_path_utils.form_test_build_objects_filelist(
              details[:paths][:build],
              @helper.fetch_shallow_source_includes( details[:filepath] ))

          # TODO: Remove any source file objects partials are standing in for
          # Redefine test_objects, removing any problematic object file that would otherwise get linked into the test executable
          test_objects = (test_objects.uniq - test_no_link_objects)

          @lock.synchronize do
            details[:sources]         = test_sources
            details[:frameworks]      = test_frameworks
            details[:core]            = test_core
            details[:objects]         = test_objects
            details[:executable]      = test_executable
            details[:no_link_objects] = test_no_link_objects
            details[:results_pass]    = test_pass
            details[:results_fail]    = test_fail
            details[:tool]            = TOOLS_TEST_COMPILER
          end
        end
      end

      # Prepare to Parallelize ALL the build objects
      objects = @testables.map do |_, details| 
        details[:objects].map do |obj|
          { 
            tool: details[:tool],
            test: details[:name],
            msg:  details[:msg],
            obj:  obj
          }
        end
      end.flatten

      # Build All Test objects
      @batchinator.build_step("Building Objects") do
        @batchinator.exec(workload: :compile, things: objects) do |obj|
          src = @file_finder.find_build_input_file(filepath: obj[:obj], context: context)
          compile_test_component(tool: obj[:tool], context: context, test: obj[:test], source: src, object: obj[:obj], msg: obj[:msg])
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

          @helper.generate_executable_now(**arg_hash)
        end
      end

      # Execute Final Tests
      @batchinator.build_step("Executing") {
        results = @batchinator.exec(workload: :test, things: @testables) do |_, details|
          begin
            arg_hash = {
              context:        context,
              test_name:      details[:name],
              test_filepath:  details[:filepath],
              executable:     details[:executable],
              result:         details[:results_pass],
              options:        options              
            }

            @helper.run_fixture_now(**arg_hash)

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
    # Runtime errors (parent is Exception) continue on up to be handled by Ruby itself.
    rescue StandardError => ex
      @application.register_build_failure

      @loginator.log( ex.message, Verbosity::ERRORS, LogLabels::EXCEPTION )

      # Debug backtrace (only if debug verbosity)
      @loginator.log_debug_backtrace( ex )
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
    testable = @testables[test.to_sym]
    filepath = testable[:filepath]
    defines = testable[:compile_defines]

    # Tailor search path:
    #  1. Remove duplicates.
    #  2. If it's compilations of vendor / support files, reduce paths to only framework & support paths
    #     (e.g. we don't need all search paths to compile unity.c).
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
