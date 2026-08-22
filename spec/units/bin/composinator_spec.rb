# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'composinator'
require 'ceedling/constants'
require 'ceedling/config/config_walkinator'
require 'deep_merge'

describe Composinator do
  before(:each) do
    # Real instance -- simple utility class with no dependencies of its own,
    # and #default_tasks's behavior is easiest to verify accurately this way.
    @config_walkinator  = ConfigWalkinator.new
    @projectinator      = double('projectinator')
    @mixin_resolvinator = double('mixin_resolvinator')
    @mixinator          = double('mixinator')

    @composinator = described_class.new({
      :config_walkinator  => @config_walkinator,
      :projectinator      => @projectinator,
      :mixin_resolvinator => @mixin_resolvinator,
      :mixinator          => @mixinator,
    })
  end

  # Stubs every collaborator #loadinate touches except assemble_mixins, so a
  # test can observe exactly what cmdline sequence reaches it without needing
  # a real project file, real mixin files, or real YAML.
  def stub_loadinate_pipeline(config: {})
    allow(@projectinator).to receive(:load).and_return( ['/proj/project.yml', config] )
    allow(@projectinator).to receive(:lookup_yaml_extension).and_return( '.yml' )
    allow(@mixin_resolvinator).to receive(:extract_mixins).and_return( [[], []] )
    allow(@mixin_resolvinator).to receive(:validate_mixin_load_paths)
    allow(@mixin_resolvinator).to receive(:validate_mixins).and_return( true )
    allow(@mixin_resolvinator).to receive(:lookup_mixins) {|mixins:, **| mixins }
    allow(@mixinator).to receive(:validate_cmdline_yaml_strings)
    allow(@mixinator).to receive(:fetch_env_filepaths).and_return( [] )
    allow(@mixinator).to receive(:validate_env_filepaths)
    allow(@mixinator).to receive(:mixin)
  end

  describe '#loadinate -- cmdline mixin ordering' do
    it 'positions a repeated --mixin value at its last-typed occurrence, not its first' do
      stub_loadinate_pipeline

      captured_cmdline = nil
      allow(@mixinator).to receive(:assemble_mixins) do |config:, env:, cmdline:|
        captured_cmdline = cmdline
        []
      end

      @composinator.loadinate(
        filepath: 'project.yml',
        mixins: ['foo.yml', 'bar.yml', 'foo.yml'],
        env: {}
      )

      # The user's actual last-typed flag was `foo.yml` -- it must end up last
      # (highest priority), with `bar.yml` before it, and the earlier, now-
      # superseded `foo.yml` occurrence dropped entirely.
      expect(captured_cmdline.map {|e| e[:_input]}).to eq(['bar.yml', 'foo.yml'])
    end

    it 'leaves distinct cmdline mixin values in their original left-to-right order' do
      stub_loadinate_pipeline

      captured_cmdline = nil
      allow(@mixinator).to receive(:assemble_mixins) do |config:, env:, cmdline:|
        captured_cmdline = cmdline
        []
      end

      @composinator.loadinate(
        filepath: 'project.yml',
        mixins: ['foo.yml', 'bar.yml', 'baz.yml'],
        env: {}
      )

      expect(captured_cmdline.map {|e| e[:_input]}).to eq(['foo.yml', 'bar.yml', 'baz.yml'])
    end
  end

  describe '#loadinate -- return value' do
    it 'returns the project filepath and the loaded config hash' do
      config = {}
      stub_loadinate_pipeline(config: config)
      allow(@mixinator).to receive(:assemble_mixins).and_return( [] )

      filepath, returned_config = @composinator.loadinate(
        filepath: 'project.yml',
        mixins: [],
        env: {}
      )

      expect(filepath).to eq('/proj/project.yml')
      expect(returned_config).to equal(config)
    end
  end

  describe '#loadinate -- --mixin sigil parsing' do
    it 'strips the = sigil and routes the value to inline YAML validation' do
      stub_loadinate_pipeline

      captured_yaml_strings = nil
      allow(@mixinator).to receive(:validate_cmdline_yaml_strings) {|strings| captured_yaml_strings = strings }
      allow(@mixinator).to receive(:assemble_mixins).and_return( [] )

      @composinator.loadinate(
        filepath: 'project.yml',
        mixins: ['=:project: {}'],
        env: {}
      )

      expect(captured_yaml_strings).to eq([':project: {}'])
    end

    it 'strips the @ sigil and treats the value as an ordinary file/name reference' do
      stub_loadinate_pipeline

      captured_cmdline = nil
      allow(@mixinator).to receive(:assemble_mixins) do |cmdline:, **|
        captured_cmdline = cmdline
        []
      end

      @composinator.loadinate(
        filepath: 'project.yml',
        mixins: ['@explicit.yml'],
        env: {}
      )

      expect(captured_cmdline.map {|e| e[:_input]}).to eq(['explicit.yml'])
    end

    it 'treats a value with no sigil the same as an @-prefixed value' do
      stub_loadinate_pipeline

      captured_cmdline = nil
      allow(@mixinator).to receive(:assemble_mixins) do |cmdline:, **|
        captured_cmdline = cmdline
        []
      end

      @composinator.loadinate(
        filepath: 'project.yml',
        mixins: ['plain_name'],
        env: {}
      )

      expect(captured_cmdline.map {|e| e[:_input]}).to eq(['plain_name'])
    end

    it 'preserves left-to-right order across a mix of inline YAML, @, and bare entries' do
      stub_loadinate_pipeline

      captured_cmdline = nil
      allow(@mixinator).to receive(:validate_cmdline_yaml_strings)
      allow(@mixinator).to receive(:assemble_mixins) do |cmdline:, **|
        captured_cmdline = cmdline
        []
      end

      @composinator.loadinate(
        filepath: 'project.yml',
        mixins: ['@explicit.yml', '=:key: value', 'plain_name'],
        env: {}
      )

      expect(captured_cmdline.map {|e| e[:_input]}).to eq(['explicit.yml', ':key: value', 'plain_name'])
    end
  end

  describe '#loadinate -- load path precedence' do
    it 'orders load paths as user :load_paths, then project directory, then built-in paths' do
      stub_loadinate_pipeline
      allow(@mixin_resolvinator).to receive(:extract_mixins).and_return( [[], ['user/path']] )

      captured_load_paths = nil
      allow(@mixin_resolvinator).to receive(:lookup_mixins) do |load_paths:, **|
        captured_load_paths = load_paths
        []
      end
      allow(@mixinator).to receive(:assemble_mixins).and_return( [] )

      @composinator.loadinate(
        builtin_load_paths: ['builtin/path'],
        filepath: 'project.yml',
        mixins: [],
        env: {}
      )

      expect(captured_load_paths).to eq(['user/path', '/proj', 'builtin/path'])
    end
  end

  describe '#default_tasks' do
    it 'uses config :project ↳ :default_tasks when present' do
      config = {:project => {:default_tasks => ['test:all', 'release']}}

      result = @composinator.default_tasks( config: config, default_tasks: ['test:all'] )

      expect(result).to eq(['test:all', 'release'])
    end

    it 'returns a copy of the config value rather than the same Array object' do
      config_tasks = ['test:all']
      config = {:project => {:default_tasks => config_tasks}}

      result = @composinator.default_tasks( config: config, default_tasks: [] )

      expect(result).to_not equal(config_tasks)
    end

    it 'falls back to the given default and records it in config when :default_tasks is absent' do
      config = {}

      result = @composinator.default_tasks( config: config, default_tasks: ['test:all'] )

      expect(result).to eq(['test:all'])
      expect(config[:project][:default_tasks]).to eq(['test:all'])
    end

    it 'preserves other existing :project keys when recording the fallback default' do
      config = {:project => {:build_root => 'build'}}

      @composinator.default_tasks( config: config, default_tasks: ['test:all'] )

      expect(config[:project][:build_root]).to eq('build')
      expect(config[:project][:default_tasks]).to eq(['test:all'])
    end
  end
end
