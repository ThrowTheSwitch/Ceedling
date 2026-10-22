# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/includes/includes'
require 'ceedling/file_path_utils'
require 'rake'

class Generator

  constructor :configurator,
              :generator_helper,
              :generator_mocks,
              :generator_test_results,
              :generator_test_results_backtrace,
              :generator_partials,
              :test_context_extractor,
              :tool_executor,
              :file_finder,
              :file_path_utils,
              :reportinator,
              :loginator,
              :plugin_manager,
              :test_runner_manager,
              :system_wrapper,
              :file_wrapper


  def setup()
    # Aliases
    @helper = @generator_helper
    @backtrace = @generator_test_results_backtrace

    # Test fixtures run in parallel, and the :gdb fallback is noted once per build
    @mutex = Mutex.new
    @gdb_fallback_noted = false
  end

  # A module's typedefs and aggregate definitions are identical regardless of whether a test
  # file tests it, mocks it, or both, so they're generated once into their own header here
  # rather than duplicated by generate_partial_implementation and generate_partial_interface.
  # Returns the bare generated filename (for the caller to add to each header's own includes
  # list) or nil when the module has no typedefs or aggregate definitions to share.
  def generate_partial_types(name:, partial:, c_module:, output_path:, includes: [], include_guard: nil)
    msg = @reportinator.generate_module_progress(
      operation: "Generating shared Partial types for",
      module_name: name,
      filename: partial # Partial module name, not filename
    )
    @loginator.log( msg )

    arg_hash = {
      :name => partial, # Module name, not test name -- two modules Partialed in the same
                        # test file must not collide on one shared types header filename
      :c_module => c_module,
      :output_path => output_path,
      :includes => includes,
      :include_guard => include_guard
    }

    return @generator_partials.generate_types( **arg_hash )
  end

  def generate_partial_interface(test:, partial:, function_declarations:, includes:, c_module:, input_filepath:, output_path:, include_guard: nil)
    msg = @reportinator.generate_module_progress(
      operation: "Generating Partial mockable interface for",
      module_name: test,
      filename: partial # Partial module name, not filename
    )
    @loginator.log( msg )

    arg_hash = {
      :test => test,
      :name => partial,
      :function_declarations => function_declarations,
      :includes => includes,
      :c_module => c_module,
      :output_path => output_path,
      :include_guard => include_guard
    }

    return @generator_partials.generate_interface( **arg_hash )
  end

  def generate_partial_implementation(
      test:,
      partial:,
      function_definitions:,
      source_includes:,
      header_includes:,
      c_module:,
      input_filepath:,
      output_path:,
      include_guard: nil
    )

    msg = @reportinator.generate_module_progress(
      operation: "Generating Partial implementation for",
      module_name: test,
      filename: partial # Partial module name, not filename
    )
    @loginator.log( msg )

    arg_hash = {
      :function_definitions => function_definitions,
      :test => test,
      :name => partial,
      :source_includes => source_includes,
      :header_includes => header_includes,
      :c_module => c_module,
      :output_path => output_path,
      :include_guard => include_guard
    }

    return @generator_partials.generate_implementation( **arg_hash )
  end

  def generate_mock(context:, mock:, test:, input_filepath:, output_path:, folder: nil, overrides: {})
    arg_hash = {
      :header_file => input_filepath,
      :test => test,
      :context => context,
      :output_path => output_path }
    
    @plugin_manager.pre_mock_generate( arg_hash )

    begin
      # Below is a workaround that instantiates CMock anew:
      #  1. To allow dfferent output path per mock
      #  2. To avoid any thread safety complications

      # TODO:
      #  - Add option to CMock to generate mock to any destination path
      #  - Make CMock thread-safe

      # Get default config created by Ceedling and customize it
      # CMock writes to its root plus `folder`. That folder always ends `output_path`.
      mock_root = folder ? output_path.delete_suffix( File.join( '', folder ) ) : output_path
      config = @generator_mocks.build_configuration( mock_root, overrides: overrides )
  
      # Generate mock
      msg = @reportinator.generate_module_progress(
        operation: "Generating mock for",
        module_name: test,
        filename: File.basename(input_filepath)
      )
      @loginator.log( msg )

      cmock = @generator_mocks.manufacture( config )
      cmock.setup_mocks( arg_hash[:header_file], folder )
    rescue StandardError => ex
      # Re-raise execption but decorate it with CMock to better identify it
      raise( ex, "CMock >> #{ex.message}", ex.backtrace )
    ensure
      @plugin_manager.post_mock_generate( arg_hash )
    end
  end

  # @param mocks: Array of Mocks to include in the runner
  # @param includes: Array of Includes without mocks to include in the runner
  def generate_test_runner(context:, mocks:, includes:, test_filepath:, input_filepath:, runner_filepath:)
    arg_hash = {
      :context => context,
      :test_file => test_filepath,
      :input_file => input_filepath,
      :runner_file => runner_filepath}

    @plugin_manager.pre_runner_generate( arg_hash )

    # Collect info we need
    module_name = File.basename( arg_hash[:test_file] )

    msg = @reportinator.generate_progress("Generating runner for #{module_name}")
    @loginator.log( msg )

    unity_test_runner_generator = 
      @test_context_extractor.lookup_test_runner_generator( test_filepath )

    if unity_test_runner_generator.nil?
      msg = "Could not find test runner generator for #{test_filepath}"
      raise CeedlingException.new( msg )
    end

    # Further filter others to remove vendor files
    others = includes.reject do |include|
      VENDORS_FILES.include?( include.filename.ext() )
    end

    # Build runner file
    begin
      unity_test_runner_generator.generate(
        module_name: module_name,
        runner_filepath: runner_filepath,
        mocks: mocks,
        includes: others
      )
    rescue StandardError => ex
      # Re-raise execption but decorate it to better identify it in Ceedling output
      raise( ex, "Unity Runner Generator >> #{ex.message}", ex.backtrace )
    ensure
      @plugin_manager.post_runner_generate(arg_hash)
    end
  end

  # `compile_source` is the file actually handed to the compiler when it differs from
  # `source`, such as an isolated copy. Plugins and logs still see `source`, and get
  # `:compile_source` too so a command naming the copy can be traced to the original.
  def generate_object_file_c(
      tool:,
      module_name:,
      context:,
      source:,
      object:,
      search_paths:[],
      flags:[],
      defines:[],
      list:'',
      dependencies:'',
      msg:nil,
      compile_source:nil
    )

    shell_result = {}
    arg_hash = { :tool => tool,
                 :module_name => module_name,
                 :operation => OPERATION_COMPILE_SYM,
                 :context => context,
                 :source => source,
                 :object => object,
                 :search_paths => search_paths,
                 :flags => flags,
                 :defines => defines,
                 :list => list,
                 :dependencies => dependencies,
                 :compile_source => compile_source,
                 :msg => String(msg)
               }

    @plugin_manager.pre_compile_execute(arg_hash)

    msg = arg_hash[:msg]
    msg = @reportinator.generate_module_progress(
      operation: "Compiling",
      module_name: module_name,
      filename: File.basename(arg_hash[:source])
      ) if msg.empty?
    @loginator.log( msg )

    command =
      @tool_executor.build_command_line(
        arg_hash[:tool],
        # Extra arguments
        arg_hash[:flags],
        # Argument replacement
        compile_source || arg_hash[:source],
        arg_hash[:object],
        arg_hash[:list],
        arg_hash[:dependencies],
        arg_hash[:search_paths],
        arg_hash[:defines]
      )

    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellException => ex
      shell_result = ex.shell_result
      raise ex
    ensure
      arg_hash[:shell_command] = command[:line]
      arg_hash[:shell_result] = shell_result
      @plugin_manager.post_compile_execute(arg_hash)
    end
  end

  def generate_object_file_asm(
      tool:,
      module_name:,
      context:,
      source:,
      object:,
      search_paths:[],
      flags:[],
      defines:[],
      list:'',
      dependencies:'',
      msg:nil
    )

    shell_result = {}

    arg_hash = { :tool => tool,
                 :module_name => module_name,
                 :operation => OPERATION_ASSEMBLE_SYM,
                 :context => context,
                 :source => source,
                 :object => object,
                 :search_paths => search_paths,
                 :flags => flags,
                 :defines => defines,
                 :list => list,
                 :dependencies => dependencies
               }

    @plugin_manager.pre_compile_execute(arg_hash)

    msg = String(msg)
    msg = @reportinator.generate_module_progress(
      operation: "Assembling",
      module_name: module_name,
      filename: File.basename(arg_hash[:source])
      ) if msg.empty?
    @loginator.log( msg )

    command =
      @tool_executor.build_command_line( 
        arg_hash[:tool],
        # Extra arguments
        arg_hash[:flags],
        # Argument replacement
        arg_hash[:source],
        arg_hash[:object],
        arg_hash[:search_paths],
        arg_hash[:defines],
        arg_hash[:list],
        arg_hash[:dependencies]
      )

    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellException => ex
      shell_result = ex.shell_result
      raise ex
    ensure
      arg_hash[:shell_command] = command[:line]
      arg_hash[:shell_result] = shell_result
      @plugin_manager.post_compile_execute(arg_hash)
    end
  end

  # Windows' Installer Detection, part of User Account Control, demands administrator rights
  # to run an executable whose name looks like an installer's. A manifest requesting the
  # invoker's own rights turns it off, and is written only when missing or different.
  def generate_test_executable_manifest(executable:, test_filepath:)
    return unless @system_wrapper.windows?

    manifest = "#{executable}.manifest"
    unless @file_wrapper.exist?( manifest ) && @file_wrapper.read( manifest ) == TEST_EXECUTABLE_MANIFEST
      @file_wrapper.write( manifest, TEST_EXECUTABLE_MANIFEST )
    end

    note_installer_name( File.basename( test_filepath ) )
  end

  def generate_executable_file(tool, context, objects, flags, executable, map='', libraries=[], libpaths=[])
    shell_result = {}
    arg_hash = { :tool => tool,
                 :context => context,
                 :objects => objects,
                 :flags => flags,
                 :executable => executable,
                 :map => map,
                 :libraries => libraries,
                 :libpaths => libpaths
               }

    @plugin_manager.pre_link_execute(arg_hash)

    msg = @reportinator.generate_progress("Linking #{File.basename(arg_hash[:executable])}")
    @loginator.log( msg )

    command =
      @tool_executor.build_command_line(
        arg_hash[:tool],
        # Extra arguments
        arg_hash[:flags],
        # Argument replacement
        arg_hash[:objects],
        arg_hash[:executable],
        arg_hash[:map],
        arg_hash[:libraries],
        arg_hash[:libpaths]
      )

    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellException => ex
      shell_result = ex.shell_result
      raise ex
    ensure
      arg_hash[:shell_command] = command[:line]
      arg_hash[:shell_result] = shell_result
      @plugin_manager.post_link_execute(arg_hash)
    end
  end

  # `skipped: true` means the executable didn't need relinking (see
  # TestBuildExecutor#stage_execute) -- its cached result from the last real
  # run is reported instead of re-running it. Both fixture-execute hooks still
  # fire either way, so plugins that accumulate per-run state from them (e.g.
  # the live test summary) see this target on every run, not only when it's
  # actually rebuilt. A damaged or missing cached result normally makes the
  # fixture target stale first, since stage_execute records it as an output. If
  # none exists here anyway, this falls back to a real run.
  def generate_test_results(tool:, context:, test_name:, test_filepath:, executable:, result:, skipped: false)
    arg_hash = fixture_arg_hash(
      tool: tool, context: context, test_name: test_name, test_filepath: test_filepath, executable: executable, result_file: result
    )

    @plugin_manager.pre_test_fixture_execute( arg_hash )

    cached = skipped ? @generator_test_results.read_cached_results( result ) : nil
    return report_cached_results( arg_hash, cached ) if cached

    @loginator.log( arg_hash[:msg] )

    shell_result = run_test_fixture( arg_hash )
    shell_result = handle_test_crash( arg_hash, shell_result ) if test_crash?( arg_hash, shell_result )

    return write_test_results( arg_hash, shell_result )
  end

  # Flushes the whole-suite gdb health check accumulated across every crashing test
  # executable's `do_gdb` retry in this run. Call once, after every test executable
  # in the suite has finished executing and before final results reporting -- see
  # `GeneratorTestResultsBacktrace#report_gdb_attach_health`. A no-op run (`:none` or
  # `:simple` backtraces, or no crashes at all) never accumulates anything here.
  def report_gdb_attach_health()
    @backtrace.report_gdb_attach_health()
  end

  ### Private ###

  private

  def fixture_arg_hash(**fields)
    return fields.merge( msg: @reportinator.generate_progress( "Running #{File.basename( fields[:executable] )}" ) )
  end

  def report_cached_results(arg_hash, cached)
    arg_hash[:result_file]  = cached[:result_file]
    arg_hash[:results]      = cached[:results]
    arg_hash[:shell_result] = nil

    @plugin_manager.post_test_fixture_execute( arg_hash )
    return nil
  end

  # Unity's exit code is the number of failed tests, so the run is allowed to fail without
  # an exception, and its results are analyzed apart from tool_executor. Test case filters
  # follow the tool's own arguments, where a wrapping fixture tool runs the executable.
  def run_test_fixture(arg_hash)
    command = @tool_executor.build_command_line(
      arg_hash[:tool], [], arg_hash[:executable], trailing: @test_runner_manager.collect_cmdline_args()
    )

    command[:options][:boom] = false
    return @tool_executor.exec( command )
  end

  def test_crash?(arg_hash, shell_result)
    return @helper.test_crash?( File.basename( arg_hash[:test_filepath] ), arg_hash[:executable], shell_result )
  end

  # Lists the crashed test's cases, filtered by any matchers the build task specified, and
  # learns what it can about the crash as :project ↳ :use_backtrace allows. A crash a plugin
  # explains needs no generic notice or backtrace advice.
  def handle_test_crash(arg_hash, shell_result)
    backtrace = backtrace_for( arg_hash[:tool] )
    explanation = crash_explanation( arg_hash, shell_result, crash_notice: true )
    log_crash( arg_hash[:executable], shell_result, backtrace, explanation )

    test_cases = @test_context_extractor.lookup_test_cases( arg_hash[:test_filepath] )
    test_cases = @generator_test_results.filter_test_cases( test_cases )

    return crash_results( backtrace, arg_hash, shell_result, test_cases, explanation )
  end

  def log_crash(executable, shell_result, backtrace, explanation)
    return @helper.log_explained_crash( executable, explanation ) if explanation

    # Either the fixture tool fell back from :gdb here, or startup found gdb unable to attach
    gdb_unavailable = backtrace != @configurator.project_config_hash[:project_use_backtrace] ||
                      @configurator.gdb_backtrace_state == :fell_back
    @helper.log_test_results_crash( executable, shell_result, backtrace, gdb_unavailable: gdb_unavailable )
  end

  # A fixture tool that runs its own backtrace reruns can't run them under gdb
  def backtrace_for(tool)
    backtrace = @configurator.project_config_hash[:project_use_backtrace]
    return backtrace unless backtrace == :gdb && tool.is_a?( Hash ) && tool[:backtrace_rerun]

    note_gdb_fallback( tool )
    return :simple
  end

  def note_gdb_fallback(tool)
    @mutex.synchronize do
      return if @gdb_fallback_noted

      @gdb_fallback_noted = true
    end

    @loginator.log( "Fixture tool `#{tool[:name]}` runs its own reruns, so :use_backtrace ➡️ :gdb falls back to :simple", Verbosity::NORMAL )
  end

  # The main run's explanation serves without backtraces; each :simple rerun has its own
  def crash_results(backtrace, arg_hash, shell_result, test_cases, explanation)
    filename, executable, context = File.basename( arg_hash[:test_filepath] ), arg_hash[:executable], arg_hash[:context]
    explain = ->(result) { crash_message( crash_explanation( arg_hash, result ) ) }

    case backtrace
    when :gdb    then @backtrace.do_gdb( filename, executable, shell_result, test_cases, context: context )
    when :simple then @backtrace.do_simple( filename, executable, shell_result, test_cases, context: context, tool: arg_hash[:tool], explain: explain )
    # A crash is otherwise reported as a single failure
    else @generator_test_results.create_crash_failure( filename, shell_result, test_cases, message: crash_message( explanation ) || 'Test executable crashed' )
    end
  end

  def note_installer_name(filename)
    return unless filename.match?( WINDOWS_INSTALLER_KEYWORDS )

    msg = "Test filename `#{filename}` includes a keyword Windows recognizes as an installer (install, setup, update, patch) " \
          'when built as a test executable. As a defensive measure, Ceedling generated a manifest beside the test executable to run without ' \
          'administrator privileges. Your toolchain may already embed a manifest that does the same.'
    @loginator.log( msg, Verbosity::COMPLAIN )
  end

  # The cause of a crash, if a plugin recognizes it (e.g. a sanitizer's finding). Only the
  # main run's explanation reaches a crash notice; a backtrace rerun's reaches its failure.
  def crash_explanation(arg_hash, shell_result, crash_notice: false)
    explaining = arg_hash.merge(
      shell_result: shell_result, crash_notice: crash_notice, explanation: nil, explanation_details: nil, explanation_heading: nil
    )
    @plugin_manager.explain_test_crash( explaining )
    return nil unless explaining[:explanation]

    return { heading: explaining[:explanation_heading], cause: explaining[:explanation], details: Array( explaining[:explanation_details] ) }
  end

  # A test failure's message is a single line
  def crash_message(explanation)
    return nil unless explanation
    return explanation[:cause] if explanation[:details].empty?

    return "#{explanation[:cause]} (#{explanation[:details].join( '; ' )})"
  end

  # The caller already knows which test this run belongs to. Rediscovering it from the
  # executable's bare basename would be wasteful and open to ambiguity.
  def write_test_results(arg_hash, shell_result)
    shell_result[:executable]  = arg_hash[:executable]
    shell_result[:result_file] = arg_hash[:result_file]
    shell_result[:test_file]   = arg_hash[:test_filepath]
    processed = @generator_test_results.process_and_write_results( shell_result )

    arg_hash[:result_file]  = processed[:result_file]
    arg_hash[:results]      = processed[:results]
    # For raw output display if no plugins enabled for nice display
    arg_hash[:shell_result] = shell_result

    @plugin_manager.post_test_fixture_execute( arg_hash )
    return shell_result
  end

end
