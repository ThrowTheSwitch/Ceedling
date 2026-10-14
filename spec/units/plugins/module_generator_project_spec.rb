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
    # Test defines as a build resolves them for each test file
    let(:resolved) { { 'test/test_widget.c' => ['UNIT_TEST=1', 'OTHER'], 'test/test_gadget.c' => ['OTHER'] } }
    let(:project)  { described_class.new( {}, test_defines: ->( path ) { resolved.fetch( path, [] ) } ) }

    it 'finds a symbol among the defines resolved for that test file, with or without a value' do
      expect(project.test_defined?( 'UNIT_TEST', 'test/test_widget.c' )).to be true
      expect(project.test_defined?( 'OTHER', 'test/test_gadget.c' )).to be true
    end

    it 'reports a symbol the defines resolved for that test file lack' do
      expect(project.test_defined?( 'UNIT_TEST', 'test/test_gadget.c' )).to be false
      expect(project.test_defined?( 'UNIT_TEST', 'test/test_other.c' )).to be false
    end
  end

  describe '#same_named' do
    let(:project) do
      described_class.new(
        { collection_all_source:  ['src/Widget.c', 'lib/net/Socket.c'],
        collection_all_headers: ['inc/net/Widget.h'],
        collection_all_tests:   ['test/test_Socket.c'] },
        test_defines: ->( _path ) { [] }
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
