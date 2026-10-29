# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'tmpdir'
require 'fileutils'

REPO_ROOT = File.expand_path( '../../..', __dir__ )
$LOAD_PATH.unshift( File.join( REPO_ROOT, 'lib' ), File.join( REPO_ROOT, 'vendor/cmock/lib' ) )

require 'fff.rb'

# GH #1377: A fake gets the extra includes CMock would give a mock of the same header.
# Each example runs the wrapper Ceedling swaps in for CMock, with Ceedling's own
# :includes default, and reads back the files it writes.
describe FffCMockWrapper do

  around(:each) do |example|
    Dir.mktmpdir do |root|
      @root = root
      @header = File.join( root, 'src', 'bar.h' )
      FileUtils.mkdir_p( File.dirname( @header ) )
      File.write( @header, "void bar_turn_on(void);\n" )
      example.run
    end
  end

  before(:each) do
    allow( $stdout ).to receive( :write )
  end

  def fake(options = {})
    mock_path = File.join( @root, 'mocks' )
    config = { :mock_prefix => 'mock_', :mock_path => mock_path, :includes => [], :verbosity => 0 }
    FffCMockWrapper.new( config.merge( options ) ).setup_mocks( @header )
    return {
      :h => File.readlines( File.join( mock_path, 'mock_bar.h' ), chomp: true ),
      :c => File.readlines( File.join( mock_path, 'mock_bar.c' ), chomp: true )
    }
  end

  def position(lines, line)
    index = lines.index( line )
    expect( index ).not_to be_nil, "expected #{line.inspect} in:\n#{lines.join( "\n" )}"
    return index
  end

  def extra_includes(lines)
    standard = ['#include <string.h>', '#include "fff.h"', '#include "fff_unity_helper.h"', '#include "bar.h"', '#include "mock_bar.h"']
    return lines.grep( /\A#include / ) - standard
  end

  it 'adds no includes when no setting names any' do
    files = fake

    expect( extra_includes( files[:h] ) ).to eq( [] )
    expect( extra_includes( files[:c] ) ).to eq( [] )
  end

  it 'includes :includes_c_pre_header in the source before the fake header' do
    files = fake( :includes_c_pre_header => ['extra_c.h'] )

    expect( position( files[:c], '#include "extra_c.h"' ) ).to be < position( files[:c], '#include "mock_bar.h"' )
  end

  it 'includes :includes_c_post_header in the source after the fake header' do
    files = fake( :includes_c_post_header => ['extra_c.h'] )

    expect( position( files[:c], '#include "extra_c.h"' ) ).to be > position( files[:c], '#include "mock_bar.h"' )
  end

  it 'includes :includes_h_pre_orig_header in the header before the original header' do
    files = fake( :includes_h_pre_orig_header => ['extra_h.h'] )

    expect( position( files[:h], '#include "extra_h.h"' ) ).to be < position( files[:h], '#include "bar.h"' )
  end

  it 'includes :includes_h_post_orig_header in the header after the original header' do
    files = fake( :includes_h_post_orig_header => ['extra_h.h'] )

    expect( position( files[:h], '#include "extra_h.h"' ) ).to be > position( files[:h], '#include "bar.h"' )
  end

  it 'merges :includes with :includes_h_pre_orig_header, :includes first, each once' do
    files = fake( :includes => ['first.h', 'both.h'], :includes_h_pre_orig_header => ['both.h', 'second.h'] )

    expect( extra_includes( files[:h] ) ).to eq( ['#include "first.h"', '#include "both.h"', '#include "second.h"'] )
  end

  it 'keeps an angle-bracket include as written and quotes a bare name' do
    files = fake( :includes_c_pre_header => ['<stdint.h>', 'extra_c.h'] )

    expect( extra_includes( files[:c] ) ).to eq( ['#include <stdint.h>', '#include "extra_c.h"'] )
  end

  it 'includes a Unity helper in the source after the fake header, by its path from the mock root' do
    helper = File.join( @root, 'support', 'helper.h' )
    FileUtils.mkdir_p( File.dirname( helper ) )
    File.write( helper, "\n" )

    files = fake( :unity_helper_path => [helper] )

    expect( position( files[:c], '#include "../support/helper.h"' ) ).to be > position( files[:c], '#include "mock_bar.h"' )
  end

end
