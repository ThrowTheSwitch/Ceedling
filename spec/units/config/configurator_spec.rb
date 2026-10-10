# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config/configurator'
require 'ceedling/ruby_expandinator'
require 'ceedling/exceptions'
require 'ceedling/constants'
require 'ceedling/tool_executor'
require 'ceedling/config/config_walkinator'
require 'ceedling/config/configurator_builder'
require 'ceedling/system_utils'
require 'config_yaml_helper'

describe Configurator do
  include ConfigYamlHelper

  before(:each) do
    @ruby_expandinator    = RubyExpandinator.new
    @loginator            = double('loginator').as_null_object
    # Lazy messages are built, so a fault in composing one surfaces here
    allow(@loginator).to receive(:lazy) { |*, &message| message.call }
    @configurator_setup   = double('configurator_setup').as_null_object
    @configurator_builder = double('configurator_builder').as_null_object
    @configurator_plugins = double('configurator_plugins').as_null_object
    @yaml_wrapper         = double('yaml_wrapper').as_null_object
    @system_wrapper       = double('system_wrapper').as_null_object

    @configurator = described_class.new({
      configurator_setup:   @configurator_setup,
      configurator_builder: @configurator_builder,
      configurator_plugins: @configurator_plugins,
      config_walkinator:    ConfigWalkinator.new,
      yaml_wrapper:         @yaml_wrapper,
      system_wrapper:       @system_wrapper,
      loginator:            @loginator,
      reportinator:         double('reportinator').as_null_object,
      ruby_expandinator:    @ruby_expandinator,
    })
  end

  # Minimal config skeleton with all keys required by standardize_paths.
  # Individual tests override only the section under test with dirty paths.
  def base_config
    {
      project:      { build_root: 'build/out' },
      release_build: { artifacts: 'build/release' },
      paths:        {},
      files:        {},
      tools:        {},
    }
  end

  # The probe runs with :boom false, so a failed run reports a zero exit code. Its verdict
  # must come from the process status, or a preprocessor that rejects the flag passes.
  describe "#resolve_directives_only_preprocessing" do
    def probe_config
      {
        project:    { use_test_preprocessor: :all },
        test_build: { preprocess_force_fallback: false },
        tools:      { test_file_directives_only_preprocessor: { executable: 'gcc' } },
      }
    end

    def probe_with(result)
      tool_executor = double('tool_executor')
      allow(tool_executor).to receive(:build_command_line).and_return({ options: {} })
      allow(tool_executor).to receive(:exec).and_return(result)
      allow(tool_executor).to receive(:failed?) { |r| ToolExecutor.allocate.failed?( r ) }

      config = probe_config
      @configurator.resolve_directives_only_preprocessing( config, tool_executor )
      config[:test_build][:preprocess_directives_only_available]
    end

    def status(success) = instance_double(Process::Status, success?: success)

    it "marks directives-only preprocessing available when the probe succeeds" do
      expect( probe_with({ exit_code: 0, output: '', status: status(true) }) ).to be true
    end

    it "marks it unavailable when the probe fails despite a zero exit code" do
      expect( probe_with({ exit_code: 0, output: '', status: status(false) }) ).to be false
    end

    it "marks it unavailable when the preprocessor warns that it ignores the flag" do
      warning = "clang: warning: argument unused during compilation: '-fdirectives-only'"
      expect( probe_with({ exit_code: 0, output: warning, status: status(true) }) ).to be false
    end
  end

  describe "#standardize_paths" do

    it "should standardize [:project][:build_root]" do
      config = base_config
      config[:project][:build_root] = 'build\\root\\'

      @configurator.standardize_paths( config )

      expect( config[:project][:build_root] ).to eq( 'build/root' )
    end

    it "should standardize [:paths]" do
      config = base_config
      config[:paths] = { test: ['test\\src\\'] }

      @configurator.standardize_paths( config )

      expect( config[:paths][:test] ).to eq( ['test/src'] )
    end

    it "should standardize [:files]" do
      config = base_config
      config[:files] = { test: ['test\\file.c'] }

      @configurator.standardize_paths( config )

      expect( config[:files][:test].first ).to eq( 'test/file.c' )
    end

    it "should standardize [:tools] executables" do
      config = base_config
      config[:tools] = { compiler: { executable: 'path\\to\\gcc\\' } }

      @configurator.standardize_paths( config )

      expect( config[:tools][:compiler][:executable] ).to eq( 'path/to/gcc' )
    end

    it "should standardize paths at _path/_paths convention keys in any top-level section" do
      config = base_config
      config[:cmock] = { mock_path: 'build\\mocks\\' }

      @configurator.standardize_paths( config )

      expect( config[:cmock][:mock_path] ).to eq( 'build/mocks' )
    end

  end

  # Scoped narrowly to the inline Ruby string expansion (--ruby-replacement) gating
  # threaded through each call site via RubyExpandinator#expand. Uses a real
  # RubyExpandinator instance (not a double) so the enable/disable gate is exercised
  # end-to-end, mirroring ruby_expandinator_spec.rb's own coverage of the gate itself.
  describe "Ruby string expansion gating" do

    it "raises CeedlingException from #eval_paths when disabled and a path contains the pattern" do
      config = base_config
      config[:project][:build_root] = '#{1+1}'

      expect { @configurator.eval_paths( config ) }.to raise_error(CeedlingException, /:project/)
    end

    it "expands via #eval_paths when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:project][:build_root] = '#{1+1}'

      @configurator.eval_paths( config )

      expect( config[:project][:build_root] ).to eq( '2' )
    end

    it "raises CeedlingException from #eval_flags when disabled and a flag contains the pattern" do
      config = base_config
      config[:flags] = { test: { compile: ['#{1+1}'] } }

      expect { @configurator.eval_flags( config ) }.to raise_error(CeedlingException)
    end

    it "expands via #eval_flags when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:flags] = { test: { compile: ['#{1+1}'] } }

      @configurator.eval_flags( config )

      expect( config[:flags][:test][:compile] ).to eq( ['2'] )
    end

    it "raises CeedlingException from #eval_defines when disabled and a define contains the pattern" do
      config = base_config
      config[:defines] = { test: ['#{1+1}'] }

      expect { @configurator.eval_defines( config ) }.to raise_error(CeedlingException)
    end

    it "expands via #eval_defines when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:defines] = { test: ['#{1+1}'] }

      @configurator.eval_defines( config )

      expect( config[:defines][:test] ).to eq( ['2'] )
    end

    it "raises CeedlingException from #eval_environment_variables when disabled and a value contains the pattern" do
      config = base_config
      config[:environment] = [ { some_var: '#{1+1}' } ]

      expect { @configurator.eval_environment_variables( config ) }.to raise_error(CeedlingException, /:environment/)
    end

    it "expands via #eval_environment_variables when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:environment] = [ { some_var: '#{1+1}' } ]

      @configurator.eval_environment_variables( config )

      expect( config[:environment].first[:some_var] ).to eq( '2' )
    end

    it "raises CeedlingException from #prepare_plugins_load_paths when disabled and a load path contains the pattern" do
      config = base_config
      config[:plugins] = { load_paths: ['#{1+1}'] }

      expect {
        @configurator.prepare_plugins_load_paths( 'plugins/path', config )
      }.to raise_error(CeedlingException, /:plugins/)
    end

    it "expands via #prepare_plugins_load_paths when enabled" do
      @ruby_expandinator.enable!
      config = base_config
      config[:plugins] = { load_paths: ['#{1+1}'] }

      @configurator.prepare_plugins_load_paths( 'plugins/path', config )

      expect( config[:plugins][:load_paths] ).to include( '2' )
    end

  end

  describe "#populate_test_runner_generation_config" do

    def runner_config
      {
        project:     { use_backtrace: :none },
        cmock:       { mock_prefix: 'Mock', mock_suffix: '_x', enforce_strict_ordering: true },
        unity:       { defines: ['UNITY_DEFINE'], use_param_tests: false, shuffle_tests: false },
        test_runner: { cmdline_args: false, defines: ['RUNNER_DEFINE'] },
      }
    end

    it "copies CMock options used by test runner generation" do
      config = runner_config

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:mock_prefix] ).to eq( 'Mock' )
      expect( config[:test_runner][:mock_suffix] ).to eq( '_x' )
      expect( config[:test_runner][:enforce_strict_ordering] ).to eq( true )
    end

    it "merges Unity defines and :use_param_tests into test runner config" do
      config = runner_config
      config[:unity][:use_param_tests] = true

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:defines] ).to eq( ['RUNNER_DEFINE', 'UNITY_DEFINE'] )
      expect( config[:test_runner][:use_param_tests] ).to eq( true )
    end

    it "carries :unity ↳ :shuffle_tests into test runner config when enabled" do
      config = runner_config
      config[:unity][:shuffle_tests] = true

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:shuffle_tests] ).to eq( true )
    end

    it "carries :unity ↳ :shuffle_tests into test runner config when disabled" do
      config = runner_config
      config[:unity][:shuffle_tests] = false

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:shuffle_tests] ).to eq( false )
    end

    it "forces :cmdline_args on and logs a notice when :use_backtrace is enabled" do
      config = runner_config
      config[:project][:use_backtrace] = :simple
      config[:test_runner][:cmdline_args] = false

      expect( @loginator ).to receive(:log).with( /:cmdline_args/, Verbosity::COMPLAIN, LogLabels::NOTICE )

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:cmdline_args] ).to eq( true )
    end

    it "leaves :cmdline_args untouched when :use_backtrace is :none" do
      config = runner_config
      config[:test_runner][:cmdline_args] = false

      @configurator.populate_test_runner_generation_config( config )

      expect( config[:test_runner][:cmdline_args] ).to eq( false )
    end

  end

  describe "#set_partials_derived_config" do

    def partials_config
      { project: { use_partials: true }, defines: { test: ['TEST'] }, cmock: {} }
    end

    it "does nothing when :use_partials is disabled" do
      config = partials_config
      config[:project][:use_partials] = false

      @configurator.set_partials_derived_config( config )

      expect( config[:defines][:test] ).to eq( ['TEST'] )
      expect( config[:defines] ).to_not have_key( :preprocess )
    end

    it "leaves :defines: config untouched -- CEEDLING_PARTIALS_PREFIX is TestBuildSetup's concern, delivered unconditionally alongside other framework defines" do
      config = partials_config

      @configurator.set_partials_derived_config( config )

      expect( config[:defines][:test] ).to eq( ['TEST'] )
      expect( config[:defines] ).to_not have_key( :preprocess )
    end

    it "leaves :cmock ↳ :treat_inlines untouched, whatever it was set to -- a per-mock concern handled at mock generation time, not a project-wide one settled here" do
      config = partials_config
      config[:cmock][:treat_inlines] = :include

      @configurator.set_partials_derived_config( config )

      expect( config[:cmock][:treat_inlines] ).to eq( :include )
    end

  end

  describe "#populate_partials_config / #get_partials_config" do

    it "returns the :partials section handed to populate_partials_config" do
      config = { partials: { max_extraction_length: 5000 } }

      @configurator.populate_partials_config( config )

      expect( @configurator.get_partials_config ).to eq( { max_extraction_length: 5000 } )
    end

    it "returns a clone, not the same object populate_partials_config was given -- callers may mutate their own copy freely" do
      config = { partials: { max_extraction_length: 5000 } }
      @configurator.populate_partials_config( config )

      returned = @configurator.get_partials_config
      returned[:max_extraction_length] = 1

      expect( @configurator.get_partials_config[:max_extraction_length] ).to eq( 5000 )
    end

    it "defaults to an empty hash before populate_partials_config has ever run" do
      expect( @configurator.get_partials_config ).to eq( {} )
    end

  end


  it "names only its class when inspected, rather than dumping its configuration" do
    expect( @configurator.inspect ).to eq( 'Configurator' )
  end

  describe "#set_verbosity" do
    it "defines project_debug and project_verbosity from the command line constants" do
      stub_const('PROJECT_DEBUG', true)
      stub_const('PROJECT_VERBOSITY', Verbosity::OBNOXIOUS)

      @configurator.set_verbosity()

      expect( @configurator.project_debug ).to be true
      expect( @configurator.project_verbosity ).to eq( Verbosity::OBNOXIOUS )
    end

    it "reports no debugging when the command line set none" do
      hide_const('PROJECT_DEBUG')

      @configurator.set_verbosity()

      expect( @configurator.project_debug ).to be false
    end

    it "defines them on this configurator alone" do
      stub_const('PROJECT_VERBOSITY', Verbosity::NORMAL)

      @configurator.set_verbosity()

      expect( Configurator.method_defined?( :project_verbosity ) ).to be false
    end
  end

  # Accessors belong to the configurator that built them, not to every Configurator
  describe "accessors" do
    it "are defined on this configurator alone" do
      builder = ConfiguratorBuilder.new( file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil )
      builder.constants_namespace = Module.new
      allow(@configurator_setup).to receive(:build_constants_and_accessors) { |config, target| builder.build_accessor_methods( config, target ) }

      @configurator.replace_flattened_config( { configurator_spec_setting: 3 } )

      expect( @configurator.configurator_spec_setting ).to eq( 3 )
      expect( Configurator.method_defined?( :configurator_spec_setting ) ).to be false
    end
  end

  describe "#set_partials_derived_config enabling" do
    it "enables mocking and full test preprocessing" do
      config = config_from_yaml( ":project:\n  :use_partials: true\n  :use_mocks: false\n  :use_test_preprocessor: :none\n" )

      @configurator.set_partials_derived_config( config )

      expect( config[:project] ).to include( use_mocks: true, use_test_preprocessor: :all )
    end
  end

  describe "#resolve_directives_only_preprocessing without a probe" do
    it "marks directives-only preprocessing unavailable when preprocessing is off" do
      config = { project: { use_test_preprocessor: :none }, test_build: {} }

      @configurator.resolve_directives_only_preprocessing( config, double('tool_executor') )

      expect( config[:test_build][:preprocess_directives_only_available] ).to be false
    end

    it "marks it unavailable and says so when fallback is forced" do
      config = { project: { use_test_preprocessor: :all }, test_build: { preprocess_force_fallback: true } }

      @configurator.resolve_directives_only_preprocessing( config, double('tool_executor') )

      expect( config[:test_build][:preprocess_directives_only_available] ).to be false
      expect( @loginator ).to have_received(:log).with( /Forcing fallback/, Verbosity::COMPLAIN, LogLabels::NOTICE )
    end
  end

  describe "#merge_tools_defaults" do
    def tools_for(yaml)
      defaults = { tools: {} }
      @configurator.merge_tools_defaults( config_from_yaml( yaml ), defaults )
      defaults[:tools].keys
    end

    it "adds only test tools by default" do
      expect( tools_for( ":project: {}\n" ) ).to match_array( DEFAULT_TOOLS_TEST[:tools].keys )
    end

    it "adds the preprocessors when preprocessing is on" do
      expect( tools_for( ":project:\n  :use_test_preprocessor: :mocks\n" ) ).to match_array( DEFAULT_TOOLS_TEST[:tools].keys + DEFAULT_TOOLS_TEST_PREPROCESSORS[:tools].keys )
    end

    it "adds the assembler, gdb, and release tools their settings call for" do
      tools = tools_for( <<~YAML )
        :project:
          :use_test_preprocessor: :none
          :use_backtrace: :gdb
          :release_build: true
        :test_build:
          :use_assembly: true
        :release_build:
          :use_assembly: true
      YAML

      expect( tools ).to include( :test_assembler, :test_backtrace_gdb, :release_compiler, :release_linker, :release_assembler )
    end

    it "adds copies rather than the default tool definitions themselves" do
      defaults = { tools: {} }
      @configurator.merge_tools_defaults( { project: {} }, defaults )

      expect( defaults[:tools][:test_compiler] ).to eq( DEFAULT_TOOLS_TEST[:tools][:test_compiler] )
      expect( defaults[:tools][:test_compiler] ).to_not equal( DEFAULT_TOOLS_TEST[:tools][:test_compiler] )
    end
  end

  describe "#populate_cmock_defaults" do
    it "places mocks beneath the build root and passes along the verbosity" do
      stub_const('PROJECT_VERBOSITY', Verbosity::NORMAL)
      @configurator.set_verbosity()
      defaults = { cmock: {} }

      @configurator.populate_cmock_defaults( { project: { build_root: 'build' } }, defaults )

      expect( defaults[:cmock] ).to eq( mock_path: 'build/test/mocks', verbosity: Verbosity::NORMAL )
    end
  end

  describe "#prepare_plugins_load_paths" do
    it "standardizes user load paths and searches them ahead of the built-in plugins" do
      config = { plugins: { load_paths: ['support\\plugins\\'], enabled: [] } }
      allow(@configurator_plugins).to receive(:process_aux_load_paths).and_return( { beep_path: 'x' } )

      expect( @configurator.prepare_plugins_load_paths( 'ceedling/plugins', config ) ).to eq( { beep_path: 'x' } )
      expect( config[:plugins][:load_paths] ).to eq( ['support/plugins', 'ceedling/plugins'] )
    end
  end

  describe "#merge_plugins_defaults" do
    it "merges YAML defaults and then Ruby defaults, without overriding values already present" do
      allow(@configurator_plugins).to receive(:find_plugin_yml_defaults).and_return( { beep: 'beep/config/defaults.yml' } )
      allow(@configurator_plugins).to receive(:find_plugin_hash_defaults).and_return( { gcov: { gcov: { reports: ['HtmlBasic'] } } } )
      allow(@yaml_wrapper).to receive(:load).with('beep/config/defaults.yml').and_return( config_from_yaml( ":beep:\n  :on_done: :bell\n" ) )
      defaults = { beep: { on_done: :tput } }

      @configurator.merge_plugins_defaults( {}, {}, defaults )

      expect( defaults ).to eq( beep: { on_done: :tput }, gcov: { reports: ['HtmlBasic'] } )
    end

    it "names the plugin whose YAML defaults fail to load" do
      allow(@configurator_plugins).to receive(:find_plugin_yml_defaults).and_return( { beep: 'beep/config/defaults.yml' } )
      allow(@configurator_plugins).to receive(:find_plugin_hash_defaults).and_return( {} )
      allow(@yaml_wrapper).to receive(:load).and_raise( YamlLoadException.new( reason: :syntax, source: 'x', original_error: nil, message: 'bad' ) )

      expect { @configurator.merge_plugins_defaults( {}, {}, {} ) }.to raise_error( YamlLoadException, /plugin 'beep'.*bad/ )
    end
  end

  describe "#merge_ceedling_runtime_config and #populate_with_defaults" do
    it "merges runtime settings into the configuration" do
      config = { project: { build_root: 'build' } }

      @configurator.merge_ceedling_runtime_config( config, { project: { runtime: true } } )

      expect( config ).to eq( project: { build_root: 'build', runtime: true } )
    end

    it "populates defaults and then normalizes file extensions" do
      @configurator.populate_with_defaults( { a: 1 }, { b: 2 } )

      expect( @configurator_builder ).to have_received(:populate_with_defaults).with( { a: 1 }, { b: 2 } ).ordered
      expect( @configurator_builder ).to have_received(:normalize_filename_extensions).with( { a: 1 } ).ordered
    end
  end

  describe "#populate_unity_config" do
    it "adds the parameterized test support symbols when parameterized tests are in use" do
      config = config_from_yaml( ":unity:\n  :use_param_tests: true\n  :defines: [A]\n" )

      @configurator.populate_unity_config( config )

      expect( @configurator.get_unity_config[:defines] ).to eq( ['A', 'UNITY_SUPPORT_TEST_CASES', 'UNITY_SUPPORT_VARIADIC_MACROS'] )
    end

    it "leaves the symbols alone otherwise and hands out a copy" do
      config = config_from_yaml( ":unity:\n  :use_param_tests: false\n  :defines: [A]\n" )

      @configurator.populate_unity_config( config )
      @configurator.get_unity_config[:use_param_tests] = true

      expect( @configurator.get_unity_config ).to eq( use_param_tests: false, defines: ['A'] )
    end
  end

  describe "#populate_cmock_config" do
    def cmock_config(use_mocks)
      config_from_yaml( <<~YAML )
        :project:
          :use_mocks: #{use_mocks}
        :cmock:
          :plugins:
            - ignore
            - :ignore
            - expect_any_args
          :unity_helper_path: support/unity_helper.h
          :includes: [unity_helper.h]
          :defines: []
          :mock_prefix: mock_
      YAML
    end

    it "only records the configuration when mocks are off" do
      config = cmock_config(false)

      @configurator.populate_cmock_config( config )

      expect( @configurator.get_cmock_config[:plugins] ).to eq( ['ignore', :ignore, 'expect_any_args'] )
    end

    it "normalizes plugins, helper paths, includes, and the mock prefix define when mocks are on" do
      config = cmock_config(true)

      @configurator.populate_cmock_config( config )

      expect( @configurator.get_cmock_config ).to include(
        plugins:           [:ignore, :expect_any_args],
        unity_helper_path: ['support/unity_helper.h'],
        includes:          ['unity_helper.h'],
        defines:           ['CMOCK_MOCK_PREFIX=mock_']
      )
    end
  end

  describe "#populate_exceptions_config" do
    it "enables exceptions when CMock uses its CException plugin" do
      config = { project: { use_exceptions: false }, cmock: { plugins: [:cexception] }, cexception: {} }

      @configurator.populate_exceptions_config( config )

      expect( config[:project][:use_exceptions] ).to be true
    end

    it "leaves exceptions alone otherwise" do
      config = { project: { use_exceptions: false }, cmock: { plugins: [:ignore] }, cexception: {} }

      @configurator.populate_exceptions_config( config )

      expect( config[:project][:use_exceptions] ).to be false
    end
  end

  describe "#get_runner_config" do
    it "hands out a copy of the test runner configuration" do
      config = { project: { use_backtrace: :none }, cmock: {}, unity: { defines: [] }, test_runner: { defines: [] } }
      @configurator.populate_test_runner_generation_config( config )

      @configurator.get_runner_config[:mock_prefix] = 'changed'

      expect( @configurator.get_runner_config[:mock_prefix] ).to be_nil
    end
  end

  describe "#populate_tools_config" do
    it "fills in each tool's name, stderr redirect, and optional flag" do
      config = config_from_yaml( ":tools:\n  :lint:\n    :executable: lint\n  :named:\n    :name: custom\n    :stderr_redirect: :auto\n    :optional: true\n" )

      @configurator.populate_tools_config( config )

      expect( config[:tools][:lint] ).to eq( executable: 'lint', name: 'lint', stderr_redirect: StdErrRedirect::NONE, optional: false )
      expect( config[:tools][:named] ).to eq( name: 'custom', stderr_redirect: :auto, optional: true )
    end

    it "refuses a tool that is not a hash" do
      expect { @configurator.populate_tools_config( { tools: { lint: 'lint' } } ) }.to raise_error( CeedlingException, /tool :lint is a Hash but found String/ )
    end
  end

  describe "#populate_tools_shortcuts" do
    it "replaces an executable and appends arguments named by :tools_<name>" do
      config = config_from_yaml( <<~YAML )
        :tools:
          :test_compiler:
            :executable: gcc
            :arguments: [-c]
          :test_linker:
            :executable: gcc
            :arguments: []
        :tools_test_compiler:
          :executable: clang
          :arguments: [-Wall]
      YAML

      @configurator.populate_tools_shortcuts( config )

      expect( config[:tools][:test_compiler] ).to eq( executable: 'clang', arguments: ['-c', '-Wall'] )
      expect( config[:tools][:test_linker] ).to eq( executable: 'gcc', arguments: [] )
    end
  end

  describe "#discover_plugins and #populate_plugins_config" do
    it "records the Rake and programmatic plugins found" do
      allow(@configurator_plugins).to receive(:find_rake_plugins).and_return( [ { plugin: 'r', path: 'r/r.rake' } ] )
      allow(@configurator_plugins).to receive(:find_programmatic_plugins).and_return( [ { plugin: 'p', root_path: 'p' } ] )
      allow(@configurator_plugins).to receive_messages(
        rake_plugins: [ { plugin: 'r' } ], programmatic_plugins: [ { plugin: 'p' } ], config_plugins: [ { plugin: 'c' } ]
      )

      @configurator.discover_plugins( {}, {} )

      expect( @configurator.rake_plugins ).to eq( [ { plugin: 'r', path: 'r/r.rake' } ] )
      expect( @configurator.programmatic_plugins ).to eq( [ { plugin: 'p', root_path: 'p' } ] )
      expect( @configurator_plugins ).to have_received(:find_config_plugins).with( {}, {} )
    end

    it "adds each plugin's path to :plugins and shows raw test results unless told otherwise" do
      config = { plugins: { enabled: ['beep'] } }

      @configurator.populate_plugins_config( { beep_path: 'plugins/beep' }, config )

      expect( config[:plugins] ).to eq( enabled: ['beep'], display_raw_test_results: true, beep_path: 'plugins/beep' )
    end
  end

  describe "#merge_config_plugins" do
    it "does nothing without configuration plugins" do
      allow(@configurator_plugins).to receive(:config_plugins).and_return( [] )

      @configurator.merge_config_plugins( {} )

      expect( @yaml_wrapper ).to_not have_received(:load)
    end

    it "merges each plugin's configuration, resolving $PLUGIN_PATH in its :paths" do
      allow(@configurator_plugins).to receive(:config_plugins).and_return( [ { plugin: 'zap', path: 'plugins/zap/config/zap.yml' } ] )
      allow(@yaml_wrapper).to receive(:load).and_return( config_from_yaml( ":zap:\n  :level: 2\n:paths:\n  :support: [$PLUGIN_PATH/support]\n" ) )
      config = { paths: { support: ['test/support'] } }

      @configurator.merge_config_plugins( config )

      expect( config ).to eq( zap: { level: 2 }, paths: { support: ['test/support', File.expand_path( 'plugins/zap/support' )] } )
    end

    it "merges a plugin's :paths entries that do not use $PLUGIN_PATH" do
      allow(@configurator_plugins).to receive(:config_plugins).and_return( [ { plugin: 'zap', path: 'plugins/zap/config/zap.yml' } ] )
      allow(@yaml_wrapper).to receive(:load).and_return( config_from_yaml( ":paths:\n  :support: [vendor/support]\n" ) )
      config = { paths: { support: [] } }

      @configurator.merge_config_plugins( config )

      expect( config[:paths][:support] ).to eq( [ File.expand_path( 'vendor/support' ) ] )
    end

    it "names the plugin whose configuration fails to load" do
      allow(@configurator_plugins).to receive(:config_plugins).and_return( [ { plugin: 'zap', path: 'plugins/zap/config/zap.yml' } ] )
      allow(@yaml_wrapper).to receive(:load).and_raise( YamlLoadException.new( reason: :syntax, source: 'x', original_error: nil, message: 'bad' ) )

      expect { @configurator.merge_config_plugins( {} ) }.to raise_error( YamlLoadException, /plugin 'zap'.*bad/ )
    end
  end

  describe "#eval_environment_variables" do
    it "does nothing without :environment" do
      @configurator.eval_environment_variables( {} )

      expect( @system_wrapper ).to_not have_received(:env_set)
    end

    it "joins a :path list with the platform path separator and other lists with spaces, then sets each upcased" do
      config = config_from_yaml( ":environment:\n  - :path: [a, b]\n  - :cflags: [-O2, -g]\n  - :cc: gcc\n" )

      @configurator.eval_environment_variables( config )

      expect( config[:environment] ).to eq( [ { path: "a#{File::PATH_SEPARATOR}b" }, { cflags: '-O2 -g' }, { cc: 'gcc' } ] )
      expect( @system_wrapper ).to have_received(:env_set).with( 'PATH', "a#{File::PATH_SEPARATOR}b" )
      expect( @system_wrapper ).to have_received(:env_set).with( 'CFLAGS', '-O2 -g' )
      expect( @system_wrapper ).to have_received(:env_set).with( 'CC', 'gcc' )
    end
  end

  describe "#eval_environment_variables naming PATH another way" do
    it "joins a PATH list with the path separator however the name is written" do
      config = config_from_yaml( ":environment:\n  - PATH: [a, b]\n  - :Path: [c, d]\n" )

      @configurator.eval_environment_variables( config )

      expect( config[:environment] ).to eq( [ { 'PATH' => "a#{File::PATH_SEPARATOR}b" }, { Path: "c#{File::PATH_SEPARATOR}d" } ] )
    end
  end

  describe "#eval_paths" do
    it "turns a single :paths or :files string into a list" do
      config = base_config.merge( paths: { test: 'test' }, files: { source: 'src/a.c' } )

      @configurator.eval_paths( config )

      expect( config[:paths][:test] ).to eq( ['test'] )
      expect( config[:files][:source] ).to eq( ['src/a.c'] )
    end

    it "expands strings in every path setting, including the _path / _paths convention" do
      @ruby_expandinator.enable!
      config = base_config.merge(
        paths: { test: ['#{"te" + "st"}'] }, files: { source: ['#{"src"}/a.c'] }, cmock: { mock_path: '#{"mocks"}' }
      )
      config[:release_build][:artifacts] = ['#{"art"}']

      @configurator.eval_paths( config )

      expect( config[:paths][:test] ).to eq( ['test'] )
      expect( config[:files][:source] ).to eq( ['src/a.c'] )
      expect( config[:cmock][:mock_path] ).to eq( 'mocks' )
      expect( config[:release_build][:artifacts] ).to eq( ['art'] )
    end
  end

  describe "#eval_paths with an unset _path setting" do
    it "leaves the unset setting alone" do
      config = base_config.merge( unity: { helper_path: nil }, cmock: { include_paths: ['inc', nil] } )

      expect { @configurator.eval_paths( config ) }.to_not raise_error
      expect( config[:cmock][:include_paths] ).to eq( ['inc', nil] )
    end
  end

  describe "#eval_paths with an unset release artifacts path" do
    it "leaves the unset path alone" do
      config = base_config
      config[:release_build][:artifacts] = nil

      expect { @configurator.eval_paths( config ) }.to_not raise_error
    end
  end

  describe "#eval_flags and #eval_defines through matchers" do
    it "expands lists of strings at any depth" do
      @ruby_expandinator.enable!
      config = { flags: { test: { compile: { '*': ['#{"-g"}'] } } }, defines: { test: { Model: ['#{"A"}', 7] } } }

      @configurator.eval_flags( config )
      @configurator.eval_defines( config )

      expect( config[:flags][:test][:compile][:'*'] ).to eq( ['-g'] )
      expect( config[:defines][:test][:Model] ).to eq( ['#{"A"}', 7] )
    end
  end

  describe "#standardize_paths cleanup" do
    it "drops :paths and :files entries left blank" do
      config = base_config.merge( paths: { test: ['test', '  ', nil] }, files: { source: [' '] } )

      @configurator.standardize_paths( config )

      expect( config[:paths][:test] ).to eq( ['test'] )
      expect( config[:files][:source] ).to eq( [] )
    end

    it "says so when there is no :release_build section" do
      config = base_config
      config.delete( :release_build )

      @configurator.standardize_paths( config )

      expect( @loginator ).to have_received(:log).with( /:release_build section absent/, Verbosity::COMPLAIN, LogLabels::NOTICE )
    end
  end

  describe "#validate_essential and #validate_final" do
    let(:final_validations) do
      [ :validate_paths, :validate_tools, :validate_test_runner_generation, :validate_defines, :validate_flags,
        :validate_test_preprocessor, :validate_backtrace, :validate_threads, :validate_partials, :validate_plugins ]
    end

    it "passes when every essential validation passes" do
      [:validate_required_sections, :validate_required_section_values, :validate_environment_vars].each do |name|
        allow(@configurator_setup).to receive(name).and_return(true)
      end

      expect { @configurator.validate_essential( {} ) }.to_not raise_error
    end

    it "runs every essential validation before failing" do
      allow(@configurator_setup).to receive(:validate_required_sections).and_return(false)
      allow(@configurator_setup).to receive_messages( validate_required_section_values: true, validate_environment_vars: true )

      expect { @configurator.validate_essential( {} ) }.to raise_error( CeedlingException, /failed validation/ )
      expect( @configurator_setup ).to have_received(:validate_environment_vars)
    end

    it "runs every final validation, handing the test case filters to runner generation" do
      final_validations.each { |name| allow(@configurator_setup).to receive(name).and_return(true) }

      @configurator.validate_final( {}, { include_test_case: 'a', exclude_test_case: 'b' } )

      expect( @configurator_setup ).to have_received(:validate_test_runner_generation).with( {}, 'a', 'b' )
      final_validations.each { |name| expect( @configurator_setup ).to have_received(name) }
    end

    it "fails after any final validation fails" do
      final_validations.each { |name| allow(@configurator_setup).to receive(name).and_return(true) }
      allow(@configurator_setup).to receive(:validate_threads).and_return(false)

      expect { @configurator.validate_final( {}, { include_test_case: '', exclude_test_case: '' } ) }.to raise_error( CeedlingException, /failed validation/ )
    end
  end

  describe "#build and its supplements" do
    before(:each) do
      allow(@configurator_builder).to receive(:flattenify) { |config| config.transform_keys { |key| :"flat_#{key}" } }
    end

    it "flattens the configuration, builds its paths, directories, vendor files, and collections, then its constants and accessors" do
      @configurator.build( 'lib', 'logs', { a: 1, environment: [ { cc: 'gcc' } ] }, :environment )

      flattened = { flat_a: 1, flat_environment: [ { cc: 'gcc' } ] }
      expect( @configurator_setup ).to have_received(:build_project_config).with( 'lib', 'logs', flattened ).ordered
      expect( @configurator_setup ).to have_received(:build_directory_structure).with( flattened ).ordered
      expect( @configurator_setup ).to have_received(:vendor_frameworks_and_support_files).with( 'lib', flattened ).ordered
      expect( @configurator_setup ).to have_received(:build_project_collections).with( flattened ).ordered
      expect( @configurator_setup ).to have_received(:build_constants_and_accessors).with( flattened, anything ).ordered
      expect( @configurator_setup ).to have_received(:build_constants_and_accessors).with( { environment: [ { cc: 'gcc' } ] }, anything ).ordered
      expect( @configurator.project_config_hash ).to eq( flattened )
    end

    it "redefines an existing element and its constant" do
      @configurator.build( 'lib', 'logs', { a: 1 } )

      @configurator.redefine_element( 'flat_a', 2 )

      expect( @configurator.project_config_hash[:flat_a] ).to eq( 2 )
      expect( @configurator_builder ).to have_received(:build_global_constant).with( :flat_a, 2 )
    end

    it "refuses to redefine an element that does not exist" do
      expect { @configurator.redefine_element( :missing, 1 ) }.to raise_error( CeedlingException, /Could not redefine missing/ )
    end

    it "merges a supplement into the configuration and rebuilds the sections it touched" do
      base = { environment: [ { cc: 'gcc' } ] }
      @configurator.build( 'lib', 'logs', base )

      @configurator.build_supplement( base, { environment: [ { ld: 'ld' } ] } )

      expect( base[:environment] ).to eq( [ { cc: 'gcc' }, { ld: 'ld' } ] )
      expect( @configurator.project_config_hash ).to include( flat_environment: [ { cc: 'gcc' }, { ld: 'ld' } ] )
      expect( @configurator_setup ).to have_received(:build_constants_and_accessors).with( { environment: [ { cc: 'gcc' }, { ld: 'ld' } ] }, anything )
    end

    it "merges a replacement flattened configuration and rebuilds its accessors" do
      @configurator.replace_flattened_config( { flat_b: 3 } )

      expect( @configurator.project_config_hash ).to eq( flat_b: 3 )
      expect( @configurator_setup ).to have_received(:build_constants_and_accessors).with( { flat_b: 3 }, anything )
    end

    it "adds each Rake plugin to the Rakefiles to load" do
      @configurator.replace_flattened_config( { project_rakefile_component_files: ['base.rake'] } )

      @configurator.insert_rake_plugins( [ { plugin: 'r', path: 'r/r.rake' } ] )

      expect( @configurator.project_config_hash[:project_rakefile_component_files] ).to eq( ['base.rake', 'r/r.rake'] )
    end
  end

end
