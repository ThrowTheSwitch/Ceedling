# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

[File.expand_path( '../../../plugins/module_generator/lib', __dir__ ),
 File.expand_path( '../../../vendor/unity/auto', __dir__ )].each { |path| $LOAD_PATH.unshift( path ) unless $LOAD_PATH.include?( path ) }

require 'module_generator_unity'

# Only the file plan is exercised here, which Unity builds without touching the disk
describe ModuleGeneratorUnity do

  def templates(test_guard)
    generator = described_class.new( path_src: 'src', path_inc: 'inc', path_tst: 'test', test_guard: test_guard )
    return generator.files_to_operate_on( 'widget' ).to_h { |file| [File.extname( file[:path].to_s ) + file[:path].dirname.to_s, file[:template]] }
  end

  it 'keeps Unity test template under #ifdef' do
    expect(templates( 'ifdef' )['.ctest']).to eq( TEMPLATE_TST )
  end

  it 'guards the test template with #if under the #if guard' do
    expect(templates( 'if' )['.ctest']).to start_with( "#if %5$s\n" )
    expect(templates( 'if' )['.ctest']).to eq( TEMPLATE_TST.sub( '#ifdef ', '#if ' ) )
  end

  it 'leaves source and header templates alone' do
    expect(templates( 'if' )['.csrc']).to eq( TEMPLATE_SRC )
    expect(templates( 'if' )['.hinc']).to eq( TEMPLATE_INC )
  end

end
