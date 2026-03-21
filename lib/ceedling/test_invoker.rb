# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_context_extractor'
require 'ceedling/includes/includes'
require 'fileutils'

class TestInvoker

  attr_reader :sources, :tests, :mocks

  constructor(
    :application,
    :configurator,
    :test_invoker_helper,
    :plugin_manager,
    :reportinator,
    :loginator,
    :batchinator,
    :preprocessinator,
    :partializer,
    :generator,
    :test_context_extractor,
    :file_path_utils,
    :file_wrapper,
    :file_finder,
    :verbosinator
  )

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
            paths[:preprocess_files_raw_directives_only] = File.join( preprocess_files_path, PREPROCESS_RAW_DIRECTIVES_ONLY_DIR )
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
          filename = File.basename(filepath)

          # Always extract includes via regex.
          #  - In non-preprocessing builds, we only use this.
          #  - With fallback options if certain kinds of preprocessing are unavailable, use the regex includes instead.
          contexts = [TestContextExtractor::Context::INCLUDES]

          if @configurator.project_use_test_preprocessor_tests
            # TestContextExtractor::Context::INCLUDES (see above)
            msg = @reportinator.generate_progress( "Parsing #{filename} for user & system #includes (fallback for preprocessing failures)" )
            @loginator.log( msg )

            # Extracting other context will happen in later steps after preprocessing.
            contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS

            msg = @reportinator.generate_progress( "Parsing #{filename} for include path build directive macros" )
            @loginator.log( msg )

          else
            # TestContextExtractor::Context::INCLUDES (see above)
            msg = @reportinator.generate_progress( "Parsing #{filename} for user & system #includes" )
            @loginator.log( msg )

            # Extract context without preprocessing.
            contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_INCLUDE_PATHS
            contexts << TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES
            contexts << TestContextExtractor::Context::TEST_RUNNER_DETAILS

            msg = @reportinator.generate_progress( "Parsing #{filename} for build directive macros and test case names" )
            @loginator.log( msg )
          end

          # Collect test context using text scanning (no preprocessing involved here)
          @context_extractor.collect_simple_context_from_file( filepath, nil, *contexts )
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
            operation: 'Collecting search paths, flags, and defines for',
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

      @batchinator.build_step("Collecting More Test Context") do
        # Collect includes from test files
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]
          name = details[:name]

          # Skip running the preprocessor if we have good, cachced includes
          if @preprocessinator.cached_includes_list?( test: name, filepath: filepath )
            msg = @reportinator.generate_module_progress(
              operation: 'Skipping preprocessing for #includes in favor of cached #includes for',
              module_name: name,
              filename: File.basename( filepath )
            )
            @loginator.log( msg )
            next
          end

          arg_hash = {
            test:          details[:name],
            filepath:      details[:filepath],
            # For user includes preprocessing, we need at least one search path
            search_paths:  [@configurator.project_build_vendor_ceedling_path],
            flags:         details[:preprocess_flags],
            defines:       details[:preprocess_defines]
          }

          msg = @reportinator.generate_module_progress(
            operation: 'Extracting #includes from',
            module_name: name,
            filename: File.basename( filepath )
          )
          @loginator.log( msg )

          # Extract user includes
          includes = @preprocessinator.preprocess_bare_includes( **arg_hash )
          
          # Temporarily store includes for future use
          details[:preprocess][:includes] = includes
          
          # Create blank mocks and partials to keep preprocessing happy before we generate these files
          @helper.generate_test_includes_standins( name, includes )
        end

        # Generate directive-only preprocessor output only after stand-ins are present
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          # Bail out if directives-only preprocessing is not available
          # (Updated internally in @preprocessinator while raising exception handled below)
          next unless @preprocessinator.directives_only_available?

          filepath = details[:filepath]
          name = details[:name]

          # Skip trying to generate directives-only output if preprocessing for such isn't available
          unless @preprocessinator.directives_only_available?
            msg = @reportinator.generate_module_progress(
              operation: 'Will use fallback methods to extract #includes and other directives for',
              module_name: name,
              filename: File.basename( filepath )
            )
            @loginator.log( msg, Verbosity::COMPLAIN )
            next
          end

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

          _filepath = nil

          begin
            # Generate directive-only preprocessor output for test file to be used multiple times hereafter
            _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )
          rescue => ex
            msg = "Using fallback methods to extract #includes and other directives: #{ex.message}"
            @loginator.log( msg, Verbosity::COMPLAIN )
            next
          end

          # Note: _filepath could be nil
          details[:preprocess][:directives_only][:filepath] = _filepath
        end

        @batchinator.exec(workload: :compile, things: @testables) do |_, details|
          filepath = details[:filepath]
          filename = File.basename( filepath )
          name = details[:name]

          # Skip running the preprocessor if we have good, cached includes
          cached, includes = @preprocessinator.load_includes_list( test: name, filepath: filepath )
          if cached
            @context_extractor.ingest_includes( filepath, includes )
            next
          end

          # Skip using preprocessed input if directive-only preprocessor output is not available
          # The includes we already extracted with regex are all that we have
          unless @preprocessinator.directives_only_available?
            # We already have all the includes we will extract via regex
            msg = @reportinator.generate_module_progress(
              operation: 'Using fallback text-only includes extracted for',
              module_name: name,
              filename: filename
            )
            @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )
            next
          end

          directive_only_filepath = details[:preprocess][:directives_only][:filepath]
          system_includes = []
          user_includes = []

          unless directive_only_filepath.nil?
            # If directive-only preprocessor output is available, extract system includes from it
            arg_hash = {
              name:                     name,
              filepath:                 filepath,
              directives_only_filepath: directive_only_filepath
            }

            user_includes = @preprocessinator.preprocess_user_includes( **arg_hash )
            system_includes = @preprocessinator.preprocess_system_includes( **arg_hash )
          else
            # If directive-only preprocessor output is not available, use regex-extracted includes

            msg = @reportinator.generate_module_progress(
              operation: 'Using fallback text-only includes extracted for',
              module_name: name,
              filename: filename
            )
            @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

            all_includes = @context_extractor.lookup_all_header_includes_list( filepath )

            user_includes = Includes.user( all_includes )
            system_includes = Includes.system( all_includes )
          end

          # Get existing list of bare includes
          bare_includes = details[:preprocess][:includes]

          # Reconcile includes with overlapping information from extraction passes
          all_includes = Includes.reconcile(
            bare: bare_includes,
            user: user_includes,
            system: system_includes
          )

          header = "Extracted reconciled #include list from #{filepath}"
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
          test = details[:name]
          filepath = details[:filepath]

          # Runners
          runner_filepath = @file_path_utils.form_runner_filepath_from_test( filepath )
          
          # Mocks
          mocks = {}
          _mocks = @context_extractor.lookup_mock_header_includes_list( filepath )

          # Validate mocks in use
          @helper.validate_mocks_in_use( test: test, mocks: _mocks )

          _mocks.each do |include|
            name = File.basename(include.filename).ext()
            source = nil
            input = nil

            # Handle mock partial vs. (optionally preprocessed) project header
            if @helper.is_mock_partial?( include )
              source = @helper.gnerate_header_input_for_mock_partial( include, test )
              input = source
            else
              source = @helper.find_header_input_for_mock( include )
              preprocessed_input = @file_path_utils.form_preprocessed_file_filepath( source, test )
              input = (@configurator.project_use_test_preprocessor_mocks ? preprocessed_input : source)
            end

            mocks[name.to_sym] = {
              :name => name,
              :filepath => include.filepath,
              :path => include.path,
              :source => source,
              :input => input
            }
          end

          # Partials
          partials_configs = {}
          if @configurator.project_use_partials
            partials_configs = @helper.assemble_partials_config( filepath: filepath )
          end

          # Assemble results within safety of mutex
          @lock.synchronize do
            details[:runner] = {
              :output_filepath => runner_filepath,
              :input_filepath => filepath # Default of the test file
            }
            details[:mocks] = mocks
            details[:partials] = {
              :configs => partials_configs
            }

            # Trigger pre_test plugin hook after having assembled all testing context
            @plugin_manager.pre_test( filepath )
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
      @batchinator.build_step("Preprocessing for Testing & Mocking Partials") {
        # Generate directive-only preprocessor output (only if directive-only preprocessor is working))
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

          # Check for directive-only preprocessor exceptions already occurred.
          # We should not get here unless directive-only preprocessor output is available.
          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )

          # Note: _filepath could be nil
          details[:directives_only_filepath] = _filepath
        end if @preprocessinator.directives_only_available?

        # Preprocess and assemble header files
        @batchinator.exec(workload: :compile, things: partials_headers) do |details|
          config = details[:config]
          testable = details[:testable]
          name = testable[:name]
          directives_only_filepath = details[:directives_only_filepath]

          arg_hash = {
            test:                      name,
            filepath:                  config.filepath,
            directives_only_filepath:  directives_only_filepath,
            fallback:                  (!@preprocessinator.directives_only_available? or directives_only_filepath.nil?),
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
      @batchinator.build_step("Preprocessing for Testing Partials") {
        # Generate directive-only preprocessor output (only if directive-only preprocessor is working)
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

          # Check for directive-only preprocessor exceptions already occurred.
          # We should not get here unless directive-only preprocessor output is available.
          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )

          # Note: _filepath could be nil
          details[:directives_only_filepath] = _filepath
        end if @preprocessinator.directives_only_available?

        # Preprocess and assemble source files
        @batchinator.exec(workload: :compile, things: partials_sources) do |details|
          config = details[:config]
          testable = details[:testable]
          name = testable[:name]
          directives_only_filepath = details[:directives_only_filepath]

          arg_hash = {
            test:                      name,
            filepath:                  config.filepath,
            directives_only_filepath:  directives_only_filepath,
            fallback:                  (!@preprocessinator.directives_only_available? or directives_only_filepath.nil?),
            flags:                     testable[:preprocess_flags],
            include_paths:             testable[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   testable[:preprocess_defines]
          }

          config.preprocessed_filepath, config.includes = @preprocessinator.preprocess_partial_source_file( **arg_hash )
        end
      } if @configurator.project_use_partials
      
      # Generate Partials for all tests
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
          name = testable[:name]

          module_contents = @partializer.extract_module_contents(
            name,
            config,
            # Fallback
            !@preprocessinator.directives_only_available?
          )

          impl, interface = @partializer.reconstruct_functions(contents: module_contents, config: config)

          @partializer.log_extracted_functions(
            test:           name,
            module_name:    config.module,
            impl:           impl,
            interface:      interface
          )

          @partializer.log_extracted_variable_decls(
            test:           name,
            module_name:    config.module,
            decls:          module_contents.variables
          )

          arg_hash = {
            test:                  name,
            name:                  config[:module],
            function_defns:        impl,
            variable_declarations: module_contents.variables,
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

            @generator.generate_partial_implementation(**arg_hash)
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
        # Generate directive-only preprocessor output (only if directive-only preprocessor is working)
        @batchinator.exec(workload: :compile, things: mocks) do |mock|
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

          # Check for directive-only preprocessor exceptions already occurred.
          # We should not get here unless directive-only preprocessor output is available.
          _filepath = @preprocessinator.generate_directives_only_output( **arg_hash )

          if _filepath.nil?
            msg = "Failed to generate directive-only preprocessor output (fallback methods will be used) for #{filepath}"
            @loginator.log( msg, Verbosity::COMPLAIN )
          end

          mock[:directives_only_filepath] = _filepath
        end if @preprocessinator.directives_only_available?

        # Preprocess and assembe header files to be mocked
        @batchinator.exec(workload: :compile, things: mocks) do |mock|
          details = mock[:details]
          testable = mock[:testable]
          directives_only_filepath = mock[:directives_only_filepath]

          # Defaults to false for all other mocking cases
          extras = (@configurator.cmock_treat_inlines == :include)

          arg_hash = {
            test:                      testable[:name],
            filepath:                  details[:source],
            directives_only_filepath:  directives_only_filepath,
            fallback:                  (!@preprocessinator.directives_only_available? or directives_only_filepath.nil?),
            flags:                     testable[:preprocess_flags],
            include_paths:             testable[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   testable[:preprocess_defines],
            extras:                    extras
          }

          @preprocessinator.preprocess_mockable_header_file( **arg_hash )
        end
      } if @configurator.project_use_mocks and @configurator.project_use_test_preprocessor_mocks

      # Generate mocks for all tests
      @batchinator.build_step("Mocking") {
        @batchinator.exec(workload: :compile, things: mocks) do |mock| 
          details = mock[:details]
          testable = mock[:testable]

          # Support selective sub directory handling for #include "<subdir>/mock_header.h" cases.
          output_path = File.join(testable[:paths][:mocks], details[:path])
          @file_wrapper.mkdir(output_path)

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
          filepath = details[:filepath]
          filename = File.basename(filepath)
          name = details[:name]
          directives_only_filepath = details[:preprocess][:directives_only][:filepath]

          fallback = (!@preprocessinator.directives_only_available? or directives_only_filepath.nil?)

          arg_hash = {
            test:                      name,
            filepath:                  filepath,
            directives_only_filepath:  directives_only_filepath,
            fallback:                  fallback,
            # We already have the full list of includes for each test file
            includes:                  @context_extractor.lookup_all_header_includes_list( details[:filepath] ),
            flags:                     details[:preprocess_flags],
            include_paths:             details[:search_paths],
            # For user includes preprocessing, we need at least one search path
            vendor_paths:              [@configurator.project_build_vendor_ceedling_path],
            defines:                   details[:preprocess_defines]
          }

          _filepath = @preprocessinator.preprocess_test_file(**arg_hash)

          # Replace default input with preprocessed file
          @lock.synchronize { details[:runner][:input_filepath] = _filepath }

          msg = @reportinator.generate_progress( "Parsing #{filename} for test source directive macros" )
          @loginator.log( msg )

          if fallback
            # Use actual test file
            _fileapth = filepath
          else
            # If available, use compacted directives-only filepath
            _filepath = @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( filepath, name )
          end

          # Collect sources added to test build with TEST_SOURCE_FILE() directive macro from
          # reconstructed preprocessed test file.
          # TEST_SOURCE_FILE() can be within #ifdef's--this retrieves them.
          @context_extractor.collect_simple_context_from_file(
            _filepath,
            filepath,  # Actual test filepath
            TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES
          )

          # Validate test build directive source file entries via TEST_SOURCE_FILE()
          @testables.each do |_, details|
            @helper.validate_build_directive_source_files( test: name, filepath: details[:filepath] )
          end

          if @configurator.project_use_partials
            msg = @reportinator.generate_progress( "Parsing #{filename} for Partials directive macros" )
            @loginator.log( msg )

            # Collect Partials and configuration from directive macros from reconstructed preprocessed test file.
            # Macros can be within #ifdef's--this retrieves them.
            @context_extractor.collect_simple_context_from_file(
              _filepath,
              filepath,  # Actual test filepath
              TestContextExtractor::Context::PARTIALS_CONFIGURATION
            )
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
            # Mock includes
            mocks:           @test_context_extractor.lookup_mock_header_includes_list( details[:filepath] ),
            # All other includes
            includes:        @test_context_extractor.lookup_nonmock_header_includes_list( details[:filepath] ),
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
          filepath = details[:filepath]
          # Get a list of mock includes
          mock_list = @context_extractor.lookup_mock_header_includes_list( filepath )

          # Source files referenced by conventions or specified by build directives in a test file
          test_sources       =  @helper.extract_sources( context, filepath, details[:partials][:configs] )
          test_core          =  test_sources + 
                                # List of mock includes transformed to simple list of .c files
                                mock_list.map { |mock| mock.filename.ext( EXTENSION_CORE_SOURCE ) }

          # When we have a mock and an include for the same file, the mock wins
          @helper.remove_mock_original_headers(
            test_core,
            # List of mock includes as .h filenames
            mock_list.map { |mock| mock.filename }
          )
          
          # CMock + Unity + CException
          test_frameworks    = @helper.collect_test_framework_sources( !details[:mocks].empty? )
          
          # Extra suport source files (e.g. microcontroller startup code needed by simulator)
          test_support       = @configurator.collection_all_support

          compilations       =  []
          compilations       << filepath
          compilations       += test_core
          compilations       << details[:runner][:output_filepath]
          compilations       += test_frameworks
          compilations       += test_support
          compilations.uniq!

          test_objects       = @file_path_utils.form_test_build_objects_filelist( details[:paths][:build], compilations )

          test_executable    = @file_path_utils.form_test_executable_filepath( details[:paths][:build], filepath )
          test_pass          = @file_path_utils.form_pass_results_filepath( details[:paths][:results], filepath )
          test_fail          = @file_path_utils.form_fail_results_filepath( details[:paths][:results], filepath )

          # Assemble a list of object files from .c files that have been #included in the test file
          test_no_link_objects = 
            @file_path_utils.form_test_build_objects_filelist(
              details[:paths][:build],
              @helper.fetch_shallow_source_includes( filepath ))

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

      # Prepare to parallelize all the build objects
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

      # Build all test objects
      @batchinator.build_step("Building Objects") do
        @batchinator.exec(workload: :compile, things: objects) do |obj|
          src = @file_finder.find_build_input_file(filepath: obj[:obj], context: context)
          compile_test_component(
            tool: obj[:tool],
            context: context,
            test: obj[:test],
            source: src,
            object: obj[:obj],
            msg: obj[:msg]
          )
        end
      end

      # Create test binary
      @batchinator.build_step("Building Test Executables") do
        lib_args = @helper.convert_libraries_to_arguments()
        lib_paths = @helper.get_library_paths_to_arguments()
        @batchinator.exec(workload: :compile, things: @testables) do |_, details|

          # Ensure none of the original code for partials is in the test executable
          @helper.remove_partials_source_objects( details[:objects], details[:partials][:configs] )

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
      yield(test.to_s, lookup_sources(test: test))
    end
  end

  def lookup_sources(test:)
    return (@testables[test.to_sym])[:sources]
  end

  def compile_test_component(tool:, context:TEST_SYM, test:, source:, object:, msg:nil)
    testable = @testables[test.to_sym]
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
