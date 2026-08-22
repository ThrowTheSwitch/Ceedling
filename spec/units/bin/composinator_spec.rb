# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'composinator'
require 'ceedling/constants'

describe Composinator do
  before(:each) do
    @config_walkinator = double('config_walkinator')
    @projectinator      = double('projectinator')
    @mixinator          = double('mixinator')

    @composinator = described_class.new({
      :config_walkinator => @config_walkinator,
      :projectinator     => @projectinator,
      :mixinator         => @mixinator,
    })
  end

  # Stubs every collaborator #loadinate touches except assemble_mixins, so a
  # test can observe exactly what cmdline sequence reaches it without needing
  # a real project file, real mixin files, or real YAML.
  def stub_loadinate_pipeline(config: {})
    allow(@projectinator).to receive(:load).and_return( ['/proj/project.yml', config] )
    allow(@projectinator).to receive(:extract_mixins).and_return( [[], []] )
    allow(@projectinator).to receive(:lookup_yaml_extension).and_return( '.yml' )
    allow(@projectinator).to receive(:validate_mixin_load_paths)
    allow(@projectinator).to receive(:validate_mixins).and_return( true )
    allow(@projectinator).to receive(:lookup_mixins) {|mixins:, **| mixins }
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
        builtin_mixins: {},
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
        builtin_mixins: {},
        filepath: 'project.yml',
        mixins: ['foo.yml', 'bar.yml', 'baz.yml'],
        env: {}
      )

      expect(captured_cmdline.map {|e| e[:_input]}).to eq(['foo.yml', 'bar.yml', 'baz.yml'])
    end
  end
end
