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

describe ConfiguratorBuilder do

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