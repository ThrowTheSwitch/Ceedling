# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


#derived from test_graveyard/unit/busted/configurator_builder_test.rb

require 'spec_helper'
require 'ceedling/config/configurator_builder'
require 'ceedling/filename_extension'
require 'ceedling/system_utils' # Object#deep_clone

describe ConfiguratorBuilder do

  describe '#populate_with_defaults' do
    let(:builder) { ConfiguratorBuilder.new(file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil) }

    it 'copies in a missing Hash default as an unfrozen, independent clone' do
      default_tool = { :executable => 'gcc'.freeze, :arguments => ['-g'.freeze].freeze }.freeze
      defaults = { :tools => { :some_tool => default_tool } }
      config = { :tools => {} }

      builder.populate_with_defaults(config, defaults)

      expect(config[:tools][:some_tool][:executable]).to_not be_frozen
      expect(config[:tools][:some_tool][:arguments].first).to_not be_frozen
      expect(config[:tools][:some_tool][:executable]).to_not equal(default_tool[:executable])
    end

    # This is the actual gap: a project.yml that partially defines a tool already
    # present as a Hash (e.g. one plugin-config key alongside a plugin-default-only
    # tool) recurses into that existing sub-hash rather than copying it in wholesale
    # -- any of its own still-missing String/Array leaf values were, before this fix,
    # assigned by direct reference to the (often frozen, plugin-literal) default
    # value, rather than cloned the same way a wholesale-missing tool already was.
    it 'clones a String/Array leaf default even when only recursing into an already-present Hash' do
      default_tool = { :executable => 'gcc'.freeze, :arguments => ['-g'.freeze].freeze }.freeze
      defaults = { :tools => { :some_tool => default_tool } }
      config = { :tools => { :some_tool => { :ceedling_delta_probe => true } } }

      builder.populate_with_defaults(config, defaults)

      expect(config[:tools][:some_tool][:executable]).to eq('gcc')
      expect(config[:tools][:some_tool][:executable]).to_not be_frozen
      expect(config[:tools][:some_tool][:arguments]).to eq(['-g'])
      expect(config[:tools][:some_tool][:arguments].first).to_not be_frozen
      expect(config[:tools][:some_tool][:ceedling_delta_probe]).to be(true)
    end

    it 'leaves an already-present value untouched rather than overwriting it with the default' do
      defaults = { :tools => { :some_tool => { :executable => 'gcc' } } }
      config = { :tools => { :some_tool => { :executable => 'clang' } } }

      builder.populate_with_defaults(config, defaults)

      expect(config[:tools][:some_tool][:executable]).to eq('clang')
    end
  end

  describe '#normalize_filename_extensions' do
    let(:builder) { ConfiguratorBuilder.new(file_path_collection_utils: nil, loginator: nil, file_wrapper: nil, system_wrapper: nil) }

    it 'wraps every :extension child value in a FilenameExtension' do
      config = { extension: { source: '.c', assembly: ['.s', '.S'] } }
      builder.normalize_filename_extensions(config)

      expect(config[:extension][:source]).to be_a(FilenameExtension)
      expect(config[:extension][:source].to_a).to eq(['.c'])
      expect(config[:extension][:assembly]).to be_a(FilenameExtension)
      expect(config[:extension][:assembly].to_a).to eq(['.s', '.S'])
    end

    it 'does nothing when config has no :extension entry at all' do
      config = {}
      expect { builder.normalize_filename_extensions(config) }.not_to raise_error
      expect(config[:extension]).to be_nil
    end
  end
end