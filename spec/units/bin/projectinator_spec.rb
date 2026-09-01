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
# project file itself. Its former :mixins section handling now lives on
# MixinResolvinator (see mixin_resolvinator_spec.rb).
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

    @projectinator = described_class.new({
      :file_wrapper      => @file_wrapper,
      :path_validator    => @path_validator,
      :yaml_wrapper      => @yaml_wrapper,
      :loginator         => @loginator,
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

    # #1250 -- ceedling.yml as an alternative default project filename, self-documenting
    # in a way the generic project.yml isn't. Default discovery only (no --project/-p,
    # no CEEDLING_PROJECT_FILE) -- an explicit filepath or env var always wins outright,
    # as already covered above.
    it 'falls back to ceedling.yml in the working directory when project.yml is absent' do
      allow(@file_wrapper).to receive(:exist?).with('./project.yml').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('./ceedling.yml').and_return(true)
      allow(@yaml_wrapper).to receive(:load).with(File.expand_path('./ceedling.yml')).and_return({:project => {}})

      filepath, config = @projectinator.load

      expect(filepath).to eq(File.expand_path('./ceedling.yml'))
      expect(config[:history][:config].first[:mechanism]).to eq(:project)
    end

    it 'raises a CeedlingException naming both files when project.yml and ceedling.yml both exist, under default discovery' do
      allow(@file_wrapper).to receive(:exist?).with('./project.yml').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('./ceedling.yml').and_return(true)

      expect {
        @projectinator.load
      }.to raise_error( CeedlingException, a_string_matching(/project\.yml/).and(a_string_matching(/ceedling\.yml/)) )
    end

    it 'does not raise the ambiguity error when only ceedling.yml exists' do
      allow(@file_wrapper).to receive(:exist?).with('./project.yml').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('./ceedling.yml').and_return(true)
      allow(@yaml_wrapper).to receive(:load).and_return({:project => {}})

      expect { @projectinator.load }.to_not raise_error
    end

    it 'ignores ceedling.yml (no ambiguity error) when an explicit filepath argument is given, even if both default files exist' do
      allow(@file_wrapper).to receive(:exist?).and_return(true)
      allow(@yaml_wrapper).to receive(:load).and_return({:project => {}})

      expect { @projectinator.load( filepath: 'custom.yml' ) }.to_not raise_error
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
