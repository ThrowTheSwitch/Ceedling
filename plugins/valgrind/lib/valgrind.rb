# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'valgrind_constants'

class Valgrind < Plugin

  def setup
    @memory_errors   = 0
    @tests_processed = 0
    @reports_read    = 0
    @mutex = Mutex.new()

    @result_list = []

    @environment_validated = false

    # Aliases
    @configurator        = @ceedling[:configurator]
    @loginator           = @ceedling[:loginator]
    @reportinator        = @ceedling[:reportinator]
    @rake_invocation_tracker   = @ceedling[:rake_invocation_tracker]
    @plugin_manager      = @ceedling[:plugin_manager]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
    @dependinator        = @ceedling[:dependinator]
    @file_wrapper        = @ceedling[:file_wrapper]
    @system_wrapper      = @ceedling[:system_wrapper]

    # Cloned from the original, unflattened project config (project_config_hash
    # has none of this -- flattening leaves no nested :valgrind key) so the whole
    # section can ride along as dependency-tracker meta alongside the specific
    # :arguments/:tools tracking already baked into the tool hash below -- the
    # same belt-and-suspenders reasoning :cmock's own whole-section meta capture
    # already uses.
    @valgrind_config = @ceedling[:setupinator].config_hash[:valgrind].clone
  end

  # Confirms Valgrind can actually run here, then creates the artifacts directory.
  # Called externally by the plugin Rakefile's :valgrind_deps task, which every
  # `valgrind:` task depends on.
  #
  # Validation is deliberately not done in setup(). setup() runs for every Ceedling
  # command this plugin is merely enabled for, so validating there makes Valgrind a
  # hard dependency of plain `test:all`. Valgrind does not exist on Windows at all,
  # which would leave such a project unable to run any Ceedling command.
  #
  # Memoized. Every `valgrind:` task funnels through the same Rake dependency.
  def validate_environment!
    return if @environment_validated

    if @system_wrapper.windows?
      raise CeedlingException.new(
        "Valgrind does not run on Windows.\n" \
        "Remove `valgrind` from :plugins ↳ :enabled, or build in a Linux environment."
      )
    end

    begin
      @ceedling[:tool_validator].validate( tool: TOOLS_VALGRIND, boom: true )
    rescue CeedlingException => ex
      # The bare validator message only reports a missing executable. Name the
      # platform constraint too, since that is the usual reason it is missing.
      raise CeedlingException.new(
        "#{ex.message}\n" \
        "NOTE: Valgrind runs on Linux and other Unix-like systems. macOS support is limited."
      )
    end

    @file_wrapper.mkdir( VALGRIND_ARTIFACTS_PATH )

    @environment_validated = true
  end

  # Swaps in the per-test Valgrind-wrapped fixture tool ahead of TestBuildExecutor's
  # own dependency-tracker meta capture, so a change to :valgrind ↳ :arguments (or
  # :tools ↳ :valgrind itself) is what actually forces a rerun -- not the plain test
  # fixture tool this replaces.
  def pre_test_fixture_register(arg_hash)
    return unless arg_hash[:context] == VALGRIND_SYM

    @mutex.synchronize do
      @tests_processed += 1
    end

    test_name = arg_hash[:test_name]

    # Merged onto the configured tool rather than assembled from scratch. Any other
    # key a user set under :tools ↳ :valgrind, such as :stderr_redirect, survives.
    arg_hash[:tool] = TOOLS_VALGRIND.merge( :arguments => build_arguments( test_name ) )

    # The whole :valgrind config as meta, redundant alongside :arguments already
    # being part of the tool hash above -- belt-and-suspenders against a future
    # :valgrind key affecting a run this file doesn't yet know to thread through by
    # hand. Additive: merges with TestBuildExecutor's own register call for this
    # same target moments later.
    @dependinator.register( arg_hash[:target], meta: { valgrind: @valgrind_config } )
  end

  def pre_test_fixture_execute(arg_hash)
    return unless arg_hash[:context] == VALGRIND_SYM

    msg = "Running #{File.basename(arg_hash[:executable])} under Valgrind"
    arg_hash[:msg] = @reportinator.generate_progress( msg )
  end

  def post_test_fixture_execute(arg_hash)
    return unless arg_hash[:context] == VALGRIND_SYM

    result_file = arg_hash[:result_file]

    @mutex.synchronize do
      # #104 -- `[`/`]` are legal filename characters, but also regex character-class
      # syntax; interpolating PROJECT_TEST_RESULTS_PATH into this regex unescaped means
      # a literal bracket anywhere in it (e.g. a bracket-containing :build_root:) silently
      # breaks this match, and the test never gets counted here.
      if (result_file =~ /#{Regexp.escape(PROJECT_TEST_RESULTS_PATH)}/) && !@result_list.include?(result_file)
        @result_list << arg_hash[:result_file]
      end
    end

    test_name = arg_hash[:test_name]
    errors    = count_errors( test_name )

    # nil means no report could be read. count_errors already warned.
    return if errors.nil?

    @mutex.synchronize do
      @reports_read += 1
      @memory_errors += errors
    end

    return if errors == 0

    msg = "Valgrind detected #{pluralize(errors, 'memory error')} in #{test_name} ➡️ see #{report_filepath(test_name)}"
    @loginator.log( msg, Verbosity::ERRORS, LogLabels::ERROR )
  end

  def post_build(_timestamp_s)
    return unless @rake_invocation_tracker.invoked?( /^#{VALGRIND_ROOT_NAME}(:|$)/ )

    # Only present plugin-based test results if raw test results disabled by a reporting plugin
    if !@configurator.plugins_display_raw_test_results
      # Assemble test results
      results = @plugin_reportinator.assemble_test_results( @result_list )

      hash = {
        context: VALGRIND_SYM,
        results: results
      }

      verbosity = @plugin_reportinator.test_results_floor_verbosity

      # Print unit test suite results
      @plugin_reportinator.run_test_results_report( hash, verbosity )
    end

    # Reported once, here. Emitting this per erroring test repeated the same summary
    # several times with a different partial count each time.
    log_results()

    if @configurator.valgrind_fail_build && @memory_errors > 0
      msg = "Valgrind detected #{pluralize(@memory_errors, 'memory error')} across #{pluralize(@tests_processed, 'test')}"
      @plugin_manager.register_build_failure( VALGRIND_SYM, msg )
    end
  end

  private

  def xml_report_enabled?
    return @configurator.project_config_hash[:valgrind_xml_report] == true
  end

  def log_filepath(test_name)
    return File.join( VALGRIND_ARTIFACTS_PATH, "#{test_name}.log" )
  end

  def xml_filepath(test_name)
    return File.join( VALGRIND_ARTIFACTS_PATH, "#{test_name}.xml" )
  end

  # The report a user should consult, and the one errors are counted from.
  def report_filepath(test_name)
    return xml_report_enabled? ? xml_filepath( test_name ) : log_filepath( test_name )
  end

  # Assembles the full Valgrind argument list for one test.
  #
  # Suppression files lead so a user's own :arguments entries can still override
  # anything they set. `${1}` is the test executable substitution token and is always
  # last. Neither is user-visible in :valgrind configuration.
  def build_arguments(test_name)
    config = @configurator.project_config_hash

    arguments = Array( config[:valgrind_suppressions] ).map { |file| "--suppressions=\"#{file}\"" }

    arguments << "--log-file=\"#{log_filepath( test_name )}\""

    if xml_report_enabled?
      arguments << '--xml=yes'
      arguments << "--xml-file=\"#{xml_filepath( test_name )}\""
    end

    arguments += Array( config[:valgrind_arguments] )
    arguments << '${1}'

    return arguments
  end

  # Returns the memory error count for one test, or nil when no report could be read.
  #
  # Which report is authoritative depends on :xml_report. `--xml=yes` leaves the text
  # log empty, so XML is the only place errors appear once it is enabled.
  def count_errors(test_name)
    path = report_filepath( test_name )

    unless @file_wrapper.exist?( path )
      # A silent skip here reads exactly like a clean result. It is not one. The
      # memory error status of this test is unknown.
      msg = "Valgrind wrote no report for #{test_name} at #{path}. Memory error status is unknown."
      @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::WARNING )
      return nil
    end

    contents = @file_wrapper.read( path )

    # One <error> element per finding. This total matches the text report's own
    # ERROR SUMMARY count for the same run.
    return contents.scan( /<error\b/ ).length if xml_report_enabled?

    # Valgrind writes one ERROR SUMMARY per traced process. A test that forks
    # produces several, so every one is summed. Reading only the first undercounts.
    return contents.scan( /ERROR SUMMARY:\s+(\d+) errors?/ ).flatten.map( &:to_i ).sum
  end

  def log_results
    @mutex.synchronize do
      if @reports_read > 0
        msg = "\nWrote #{pluralize(@reports_read, 'Valgrind report')} to #{VALGRIND_ARTIFACTS_PATH}/"
        @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
      end
    end
  end

  def pluralize(count, word)
    "#{count} #{word}#{count == 1 ? '' : 's'}"
  end

end
