# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Shared rigging for the configurator integration specs.
#
# The configurator's whole object graph is real: Configurator, its setup, builder,
# plugins and validator collaborators, the file, system and YAML wrappers, and the tool
# validator and executor. It runs against a temp project directory and the real
# environment. Only the console and three objects outside configuration (the plugin
# manager, plugin reportinator and test runner manager) are stand-ins.
#
# A project's configuration is given as a YAML string, parsed as Ceedling parses a
# project file. `Setupinator#do_setup` then processes it exactly as a build would.

require 'tmpdir'
require 'fileutils'
require 'set'

require 'ceedling/constants'
require 'ceedling/defaults'
require 'ceedling/system_utils'
require 'ceedling/system_wrapper'
require 'ceedling/file_wrapper'
require 'ceedling/yaml_wrapper'
require 'ceedling/reportinator'
require 'ceedling/ruby_expandinator'
require 'ceedling/file_path_collection_utils'
require 'ceedling/tool_validator'
require 'ceedling/tool_executor'
require 'ceedling/tool_executor_helper'
require 'ceedling/setupinator'
require 'ceedling/config/config_walkinator'
require 'ceedling/config/configurator'
require 'ceedling/config/configurator_setup'
require 'ceedling/config/configurator_builder'
require 'ceedling/config/configurator_plugins'
require 'ceedling/config/configurator_validator'

module ConfiguratorIntegrationHelpers

  # The configurator object graph, keyed as Ceedling's own object hash keys it
  def configurator_objects(loginator)
    o = { loginator: loginator, reportinator: Reportinator.new, ruby_expandinator: RubyExpandinator.new }
    o[:verbosinator]     = double('verbosinator', should_output?: false)
    o[:system_wrapper]   = SystemWrapper.new
    o[:file_wrapper]     = FileWrapper.new( o.slice( :loginator, :verbosinator ) )
    o[:yaml_wrapper]     = YamlWrapper.new( o.slice( :file_wrapper ) )
    o[:config_walkinator] = ConfigWalkinator.new
    o[:system_utils]     = SystemUtils.new( o.slice( :system_wrapper ) )
    o[:tool_validator]   = ToolValidator.new( o.slice( :file_wrapper, :loginator, :system_wrapper, :ruby_expandinator ) )
    o[:tool_executor_helper] = ToolExecutorHelper.new( o.slice( :loginator, :system_utils, :system_wrapper, :verbosinator ) )
    o[:tool_executor]    = ToolExecutor.new( o.slice( :tool_executor_helper, :loginator, :verbosinator, :system_wrapper, :ruby_expandinator ) )
    o[:file_path_collection_utils] = FilePathCollectionUtils.new( o.slice( :file_wrapper ) )

    o[:configurator_plugins]   = ConfiguratorPlugins.new( o.slice( :file_wrapper, :system_wrapper ) )
    o[:configurator_builder]   = ConfiguratorBuilder.new( o.slice( :file_path_collection_utils, :loginator, :file_wrapper, :system_wrapper ) )
    o[:configurator_validator] = ConfiguratorValidator.new(
      o.slice( :config_walkinator, :file_wrapper, :loginator, :system_wrapper, :reportinator, :tool_validator )
    )
    o[:configurator_setup] = ConfiguratorSetup.new(
      o.slice( :configurator_builder, :configurator_validator, :configurator_plugins, :loginator, :reportinator,
               :file_wrapper, :system_wrapper, :tool_executor )
    )
    o[:configurator] = Configurator.new(
      o.slice( :configurator_setup, :configurator_builder, :configurator_plugins, :config_walkinator, :yaml_wrapper,
               :system_wrapper, :loginator, :reportinator, :ruby_expandinator )
    )

    return o
  end

  # A console stand-in that keeps every logged message for inspection
  def quiet_loginator
    loginator = double('loginator').as_null_object
    allow(loginator).to receive(:decorate) { |message, *| message }
    allow(loginator).to receive(:project_logging).and_return(false)
    allow(loginator).to receive(:log) { |message, *| logged << message.to_s }
    return loginator
  end

  def logged
    @logged ||= []
  end

  # Runs the block inside a fresh temp project directory holding `files` (path => content)
  def in_temp_project(files = {})
    Dir.mktmpdir do |dir|
      Dir.chdir( dir ) do
        files.each do |path, content|
          FileUtils.mkdir_p( File.dirname( path ) )
          File.write( path, content )
        end
        yield dir
      end
    end
  end

  # Processes `yaml` as a build's setup would and returns the object graph. A spec
  # calls remove_tracked_constants after each example to remove the global constants
  # the configuration created.
  def configure(yaml, include_test_case: '', exclude_test_case: '', plugins_path: File.join( CEEDLING_ROOT_PATH, 'plugins' ))
    objects = configurator_objects( quiet_loginator )

    # The command line sets verbosity before configuration is processed
    stub_const( 'PROJECT_VERBOSITY', Verbosity::NORMAL )
    stub_const( 'PROJECT_DEBUG', false )
    track_constants

    setupinator = Setupinator.new
    setupinator.setup
    setupinator.ceedling = objects.merge(
      plugin_manager:      double('plugin_manager', load_programmatic_plugins: nil),
      plugin_reportinator: double('plugin_reportinator', set_system_objects: nil),
      test_runner_manager: double('test_runner_manager', configure_build_options: nil, configure_runtime_options: nil)
    )

    setupinator.do_setup(
      project_config:        objects[:yaml_wrapper].load_string( yaml ),
      include_test_case:     include_test_case,
      exclude_test_case:     exclude_test_case,
      force_test_rerun:      false,
      log_filepath:          nil,
      ceedling_plugins_path: plugins_path,
      ceedling_lib_path:     File.join( CEEDLING_ROOT_PATH, 'lib', 'ceedling' ),
      logging_path:          'build/logs'
    )

    return objects
  end

  # Remembers the global constants that exist now, so those added later can be removed
  def track_constants
    @constants_before ||= Set.new( Object.constants )
  end

  def remove_tracked_constants
    return unless @constants_before
    (Object.constants - @constants_before.to_a).each { |name| Object.send( :remove_const, name ) }
    @constants_before = nil
  end

  CEEDLING_ROOT_PATH = File.expand_path( '../../..', __dir__ )

  # The smallest project configuration a build accepts
  def minimal_project_yaml
    return <<~YAML
      :project:
        :build_root: build
      :paths:
        :test: [test/**]
        :source: [src/**]
        :include: [src/**]
    YAML
  end

  def minimal_project_files
    return {
      'src/adder.c'       => "int add(int a, int b) { return a + b; }\n",
      'src/adder.h'       => "int add(int a, int b);\n",
      'test/test_adder.c' => "#include \"unity.h\"\n#include \"adder.h\"\nvoid test_add(void) {}\n"
    }
  end
end
