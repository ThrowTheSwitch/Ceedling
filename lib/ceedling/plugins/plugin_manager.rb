# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class PluginManager

  constructor :configurator, :plugin_manager_helper, :loginator, :reportinator, :system_wrapper

  def setup
    @build_fail_registry = {}
    @plugin_objects = [] # List so we can preserve order
  end

  def load_programmatic_plugins(plugins, system_objects)
    environment = []

    plugins.each do |hash|
      # Protect against instantiating object multiple times due to processing config multiple times (option files, etc)
      next if (@plugin_manager_helper.include?( @plugin_objects, hash[:plugin] ) )

      @loginator.lazy( Verbosity::OBNOXIOUS ) do 
        @reportinator.generate_progress( "Instantiating plugin class #{camelize( hash[:plugin] )}" )
      end

      begin
        @system_wrapper.require_file( "#{hash[:plugin]}.rb" )
        object = @plugin_manager_helper.instantiate_plugin( 
          camelize( hash[:plugin] ),
          system_objects,
          hash[:plugin],
          hash[:root_path]
        )
        @plugin_objects << object
        environment += object.environment

        # Add plugins to hash of all system objects
        system_objects[hash[:plugin].downcase().to_sym()] = object
      rescue 
        @loginator.log( "Exception raised while trying to load plugin: #{hash[:plugin]}", Verbosity::ERRORS, LogLabels::EXCEPTION  )
        raise # Raise again for backtrace, etc.
      end
    end

    yield( { :environment => environment } ) if (environment.size > 0)
  end

  def plugins_failed?
    return (@build_fail_registry.size > 0)
  end

  def print_plugin_failures
    return if (@build_fail_registry.size == 0)
    failures = []

    banner = @reportinator.generate_banner(
      @loginator.decorate( 'BUILD FAILURE SUMMARY', LogLabels::FAIL )
    )

    # If we only ran basic unit tests, there's no need to prefix the failure messages with the context.
    if (@build_fail_registry.keys.size == 1 and @build_fail_registry.keys[0] == TEST_SYM)
      @build_fail_registry.each do |context, messages|
        messages.each {|message| failures << message}
      end
    # Otherwise, add the context to each message so the user knows the source of the failure.
    else
      @build_fail_registry.each do |context, messages|
        messages.each {|message| failures << "[#{context.to_s.upcase}] #{message}"}
      end
    end

    @loginator.log_list( failures, "\n" + banner, Verbosity::ERRORS, LogLabels::NONE )
  end

  def register_build_failure(context, message)
    return if (message.nil? or message.empty?)

    _context = context.is_a?(Symbol) ? context : context.to_sym

    # Create a new key/value with empty list if it doesn't exist
    @build_fail_registry[_context] ||= []

    list = @build_fail_registry[_context]
    list << message if !list.include?( message )
  end

  #### execute all plugin methods ####

  def pre_mock_preprocess(arg_hash); execute_plugins(:pre_mock_preprocess, arg_hash); end
  def post_mock_preprocess(arg_hash); execute_plugins(:post_mock_preprocess, arg_hash); end

  def pre_test_preprocess(arg_hash); execute_plugins(:pre_test_preprocess, arg_hash); end
  def post_test_preprocess(arg_hash); execute_plugins(:post_test_preprocess, arg_hash); end

  def pre_mock_generate(arg_hash); execute_plugins(:pre_mock_generate, arg_hash); end
  def post_mock_generate(arg_hash); execute_plugins(:post_mock_generate, arg_hash); end

  def pre_runner_generate(arg_hash); execute_plugins(:pre_runner_generate, arg_hash); end
  def post_runner_generate(arg_hash); execute_plugins(:post_runner_generate, arg_hash); end

  def pre_compile_execute(arg_hash); execute_plugins(:pre_compile_execute, arg_hash); end
  def post_compile_execute(arg_hash); execute_plugins(:post_compile_execute, arg_hash); end

  def pre_link_execute(arg_hash); execute_plugins(:pre_link_execute, arg_hash); end
  def post_link_execute(arg_hash); execute_plugins(:post_link_execute, arg_hash); end

  def pre_test_fixture_execute(arg_hash); execute_plugins(:pre_test_fixture_execute, arg_hash); end
  def post_test_fixture_execute(arg_hash)
    # Special arbitration: Raw test results are printed or taken over by plugins handling the job
    @loginator.log( arg_hash[:shell_result][:output] ) if @configurator.plugins_display_raw_test_results

    # Core failure detection independent of any reporting plugin
    register_build_failure( arg_hash[:context], 'Unit test failures' ) if arg_hash.dig(:results, :counts, :failed).to_i > 0

    execute_plugins(:post_test_fixture_execute, arg_hash)
  end

  def pre_test(test); execute_plugins(:pre_test, test); end
  def post_test(test); execute_plugins(:post_test, test); end

  def pre_test_build(context, timestamp_s); execute_plugins(:pre_test_build, context, timestamp_s); end
  def post_test_build(context, timestamp_s); execute_plugins(:post_test_build, context, timestamp_s); end

  def pre_release_build(timestamp_s); execute_plugins(:pre_release_build, timestamp_s); end
  def post_release_build(timestamp_s); execute_plugins(:post_release_build, timestamp_s); end

  def pre_build(timestamp_s); execute_plugins(:pre_build, timestamp_s); end
  def post_build(timestamp_s); execute_plugins(:post_build, timestamp_s); end
  def post_error(timestamp_s); execute_plugins(:post_error, timestamp_s); end

  def summary; execute_plugins(:summary); end

  private ####################################

  def camelize(underscored_name)
    return underscored_name.gsub(/(_|^)([a-z0-9])/) {$2.upcase}
  end

  def execute_plugins(method, *args)
    @plugin_objects.each do |plugin|
      begin
        if plugin.respond_to?(method)
          @loginator.lazy( Verbosity::OBNOXIOUS ) do 
            @reportinator.generate_progress( "Plugin | #{camelize( plugin.name )} > :#{method}" )
          end
          plugin.send(method, *args)
        end
      rescue
        @loginator.log( "Exception raised in plugin `#{plugin.name}` within build hook :#{method}", Verbosity::ERRORS )
        raise # Raise again for backtrace, etc.
      end
    end
  end

end
