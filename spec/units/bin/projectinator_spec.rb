# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'projectinator'
require 'ceedling/constants'
require 'ceedling/exceptions'

# Covers Projectinator's namesake responsibility -- discovering and loading the
# project file itself -- as opposed to projectinator_mixin_spec.rb, which
# covers its :mixins section handling.
describe Projectinator do
  before(:each) do
    @loginator = double('loginator')
    allow(@loginator).to receive(:lazy)
    allow(@loginator).to receive(:log)

    @file_wrapper = double('file_wrapper')
    allow(@file_wrapper).to receive(:exist?).and_return(false)

    @path_validator = double('path_validator')
    allow(@path_validator).to receive(:standardize_paths) do |*paths|
      paths.map {|p| (p.nil? || p.empty?) ? p : p.gsub("\\", '/') }
    end

    @yaml_wrapper = double('yaml_wrapper')

    @system_wrapper = double('system_wrapper')
    @ruby_expandinator = double('ruby_expandinator')

    @projectinator = described_class.new({
      :file_wrapper      => @file_wrapper,
      :path_validator    => @path_validator,
      :yaml_wrapper      => @yaml_wrapper,
      :loginator         => @loginator,
      :system_wrapper    => @system_wrapper,
      :ruby_expandinator => @ruby_expandinator,
    })
  end

  # =========================================================================
  describe '#load' do
    it 'loads from an explicit filepath argument at highest priority' do
      # A leading `/` is already absolute on POSIX but means "root of the
      # current drive" on Windows, so File.expand_path prepends a drive
      # letter there -- compute the real expanded value instead of assuming
      # the input string is left unchanged.
      expanded = File.expand_path('/abs/custom.yml')
      allow(@yaml_wrapper).to receive(:load).with(expanded).and_return({:project => {}})

      filepath, config = @projectinator.load( filepath: '/abs/custom.yml', env: {'CEEDLING_PROJECT_FILE' => 'ignored.yml'} )

      expect(filepath).to eq(expanded)
      expect(config[:project]).to eq({})
    end

    it 'records cmdline-argument history with the original (non-expanded) path' do
      allow(@yaml_wrapper).to receive(:load).and_return({})

      _, config = @projectinator.load( filepath: 'custom.yml' )
      # File.expand_path resolves relative to the real working directory, so
      # only assert on the structure, not the exact absolute path.
      entry = config[:history][:config].first
      expect(entry[:type]).to eq(:file)
      expect(entry[:mechanism]).to eq(:project)
      expect(entry[:path]).to eq('custom.yml')
    end

    it 'falls back to the environment variable when no filepath argument is given' do
      # Same platform-dependent File.expand_path behavior as the cmdline
      # argument case above.
      expanded = File.expand_path('/abs/env_project.yml')
      allow(@yaml_wrapper).to receive(:load).with(expanded).and_return({:project => {}})

      filepath, config = @projectinator.load( env: {'CEEDLING_PROJECT_FILE' => '/abs/env_project.yml'} )

      expect(filepath).to eq(expanded)
      expect(config[:history][:config].first[:mechanism]).to eq(:project)
    end

    it 'falls back to the default project.yml in the working directory when available' do
      allow(@file_wrapper).to receive(:exist?).with('./project.yml').and_return(true)
      allow(@yaml_wrapper).to receive(:load).with(File.expand_path('./project.yml')).and_return({:project => {}})

      filepath, config = @projectinator.load

      expect(filepath).to eq(File.expand_path('./project.yml'))
      expect(config[:history][:config].first[:mechanism]).to eq(:project)
    end

    it 'raises when no filepath, env var, or default project.yml is available' do
      expect {
        @projectinator.load
      }.to raise_error( /No project filepath provided/ )
    end

    it 'treats a blank YAML file as an empty config hash rather than nil' do
      allow(@yaml_wrapper).to receive(:load).and_return(nil)

      _, config = @projectinator.load( filepath: 'blank.yml' )

      expect(config).to eq({:history => config[:history]})
    end

    it 'wraps a not-found YAML load failure with a clearer message' do
      allow(@yaml_wrapper).to receive(:load).and_raise(
        YamlLoadException.new( reason: :not_found, source: 'missing.yml', original_error: nil, message: 'original message' )
      )

      expect {
        @projectinator.load( filepath: 'missing.yml' )
      }.to raise_error( YamlLoadException, /Could not find project filepath/ )
    end

    it 'wraps a non-not-found YAML load failure, preserving the original message' do
      allow(@yaml_wrapper).to receive(:load).and_raise(
        YamlLoadException.new( reason: :syntax, source: 'broken.yml', original_error: nil, message: 'line 3: bad indentation' )
      )

      expect {
        @projectinator.load( filepath: 'broken.yml' )
      }.to raise_error( YamlLoadException, /line 3: bad indentation/ )
    end

    it 'logs a loading message when not silent' do
      allow(@yaml_wrapper).to receive(:load).and_return({})

      expect(@loginator).to receive(:lazy)

      @projectinator.load( filepath: 'project.yml', silent: false )
    end

    it 'does not log when silent' do
      allow(@yaml_wrapper).to receive(:load).and_return({})

      expect(@loginator).to_not receive(:lazy)

      @projectinator.load( filepath: 'project.yml', silent: true )
    end
  end

  # =========================================================================
  describe '#config_available?' do
    it 'returns true when a project file can be loaded' do
      allow(@yaml_wrapper).to receive(:load).and_return({})

      expect(@projectinator.config_available?( filepath: 'project.yml' )).to eq(true)
    end

    it 'returns false when no project file can be found' do
      expect(@projectinator.config_available?).to eq(false)
    end

    it 'returns false when the found project file fails to load' do
      allow(@yaml_wrapper).to receive(:load).and_raise(
        YamlLoadException.new( reason: :syntax, source: 'broken.yml', original_error: nil, message: 'bad yaml' )
      )

      expect(@projectinator.config_available?( filepath: 'broken.yml' )).to eq(false)
    end
  end

  # =========================================================================
  describe '#lookup_yaml_extension' do
    it 'returns the default extension when no :extension section is present' do
      expect(@projectinator.lookup_yaml_extension( config: {} )).to eq('.yml')
    end

    it 'returns the default extension when :extension is present but :yaml is not' do
      config = {:extension => {:header => '.h'}}
      expect(@projectinator.lookup_yaml_extension( config: config )).to eq('.yml')
    end

    it 'returns the configured :extension ↳ :yaml value when present' do
      config = {:extension => {:yaml => '.yaml'}}
      expect(@projectinator.lookup_yaml_extension( config: config )).to eq('.yaml')
    end
  end
end
