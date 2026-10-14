# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/module_generator/lib', __dir__ ) )

require 'module_generator_project'

describe ModuleGeneratorProject do

  describe '#test_defined?' do
    it 'finds a symbol in a plain list, with or without a value' do
      expect(described_class.new( defines_test: ['TEST'] ).test_defined?( 'TEST' )).to be true
      expect(described_class.new( defines_test: ['TEST=1'] ).test_defined?( 'TEST' )).to be true
    end

    it 'finds a symbol among per-test matchers' do
      defines = { '*' => ['OTHER'], 'test_widget' => ['CEEDLING_TEST'] }

      expect(described_class.new( defines_test: defines ).test_defined?( 'CEEDLING_TEST' )).to be true
    end

    it 'reports a symbol no test defines' do
      expect(described_class.new( defines_test: ['UNIT_TEST'] ).test_defined?( 'TEST' )).to be false
      expect(described_class.new( {} ).test_defined?( 'TEST' )).to be false
    end
  end

  describe '#same_named' do
    let(:project) do
      described_class.new(
        collection_all_source:  ['src/Widget.c', 'lib/net/Socket.c'],
        collection_all_headers: ['inc/net/Widget.h'],
        collection_all_tests:   ['test/test_Socket.c']
      )
    end

    it 'lists existing project files elsewhere that share a planned file name' do
      planned = ['src/lab/Widget.c', 'inc/lab/Widget.h', 'test/lab/test_Widget.c']

      expect(project.same_named( planned )).to eq(
        'src/lab/Widget.c' => ['src/Widget.c'], 'inc/lab/Widget.h' => ['inc/net/Widget.h']
      )
    end

    it 'ignores the planned file itself' do
      expect(project.same_named( ['./src/Widget.c'] )).to eq( {} )
    end
  end

end
