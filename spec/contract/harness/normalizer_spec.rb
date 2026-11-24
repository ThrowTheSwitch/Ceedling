# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'contract/normalizer'
require 'contract/tree_writer'

describe Contract::Normalizer do

  let( :workspace ) { Contract::Workspace.new( root: '/tmp/ws', app: '/tmp/ws/app', far: '/var/far/deep/sdk' ) }
  let( :normalizer ) { described_class.new( workspace ) }

  it 'makes a project path relative, with forward slashes and no dot segments' do
    expect( normalizer.path( '/tmp/ws/app/src/drivers/foo.h' ) ).to eq( 'src/drivers/foo.h' )
    expect( normalizer.path( './src/drivers/foo.h' ) ).to eq( 'src/drivers/foo.h' )
    expect( normalizer.path( 'src/./drivers//foo.h' ) ).to eq( 'src/drivers/foo.h' )
    expect( normalizer.path( 'src\\drivers\\foo.h' ) ).to eq( 'src/drivers/foo.h' )
    expect( normalizer.path( '"build/test/out/a.o"' ) ).to eq( 'build/test/out/a.o' )
  end

  it 'names a sibling by its climb, a far file by %{far}, and anything else as a system file' do
    expect( normalizer.path( '/tmp/ws/shared/b.h' ) ).to eq( '../shared/b.h' )
    expect( normalizer.path( '/var/far/deep/sdk/c.h' ) ).to eq( '%{far}/c.h' )
    expect( normalizer.path( '/usr/include/stdint.h' ) ).to eq( '<system>' )
    expect( normalizer.path( File.join( Contract::CHECKOUT, 'vendor', 'unity', 'src', 'unity.h' ) ) ).to eq( '%{ceedling}/vendor/unity/src/unity.h' )
  end

  it 'writes a temporary directory a build makes as <tmp>' do
    expect( normalizer.path( 'build/test/out/t/d20261124-522-t6kvro/helper.h' ) ).to eq( 'build/test/out/t/<tmp>/helper.h' )
  end

  it 'compares a Windows drive path without letter case' do
    windows = described_class.new( Contract::Workspace.new( root: 'C:/Temp/ws', app: 'C:/Temp/ws/app', far: 'D:/far' ) )
    expect( windows.path( 'c:\\temp\\ws\\app\\src\\a.h' ) ).to eq( 'src/a.h' )
  end

  it 'keeps a raw spelling as written, less the workspace prefix' do
    expect( normalizer.raw( './src/drivers/foo.h' ) ).to eq( './src/drivers/foo.h' )
    expect( normalizer.raw( '/tmp/ws/app/src/foo.h' ) ).to eq( 'src/foo.h' )
    expect( normalizer.text( 'In file /tmp/ws/app/src/a.c, done in 12 milliseconds' ) ).to eq( 'In file src/a.c, done in <time>' )
    expect( normalizer.text( 'test/t.c:6:(.text+0x1f): undefined reference' ) ).to eq( 'test/t.c:6:(.text+<offset>): undefined reference' )
  end

  describe '.parse_d' do
    it 'lists every prerequisite as written, across continued lines and phony rules' do
      text = "build/a.o: test/test_a.c src/a.h \\\n  src/sub\\ dir/b.h\nsrc/a.h:\n"
      expect( described_class.parse_d( text ) ).to eq( ['test/test_a.c', 'src/a.h', 'src/sub dir/b.h'] )
    end

    it 'keeps a drive letter colon inside a name' do
      text = "C:\\b\\a.o: C:\\w\\test\\t.c C:\\w\\src\\a.h\r\n"
      expect( described_class.parse_d( text ) ).to eq( ['C:\\w\\test\\t.c', 'C:\\w\\src\\a.h'] )
    end
  end

  describe '.parse_markers' do
    it 'lists each file the line markers name, once, without <built-in> names' do
      text = "# 0 \"test/t.c\"\n# 0 \"<built-in>\"\n# 1 \"./src/a.h\" 1\nint a;\n# 2 \"test/t.c\" 2\n"
      expect( described_class.parse_markers( text ) ).to eq( ['test/t.c', './src/a.h'] )
    end
  end

  # Fixture text copied from a Windows CI probe compiling test/t_dot.c, which includes
  # "src/drivers/bar.h", which includes "foo.h", with -I . Both compilers must normalize
  # to the Linux GCC answer.
  context 'with Windows compiler output' do
    let( :linux_answer ) { ['test/t_dot.c', 'src/drivers/bar.h', 'src/drivers/foo.h'] }

    let( :clang_d ) { "dot.o: test\\t_dot.c src\\drivers\\bar.h src\\drivers\\foo.h\r\n" }
    let( :clang_markers ) do
      [
        '# 1 "test/t_dot.c"',
        '# 1 "test/t_dot.c" 2',
        '# 1 ".\\\\src/drivers/bar.h" 1',
        '# 1 ".\\\\src/drivers\\\\foo.h" 1',
        '# 4 ".\\\\src/drivers/bar.h" 2',
        '# 2 "test/t_dot.c" 2'
      ].join( "\n" ) + "\n"
    end

    let( :mingw_d ) { "dot.o: test/t_dot.c src/drivers/bar.h src/drivers/foo.h\r\n" }
    let( :mingw_markers ) do
      [
        '# 0 "test/t_dot.c"',
        '# 1 "test/t_dot.c"',
        '# 1 "./src/drivers/bar.h" 1',
        '# 1 "./src/drivers/foo.h" 1',
        '# 4 "./src/drivers/bar.h" 2',
        '# 2 "test/t_dot.c" 2'
      ].join( "\n" ) + "\n"
    end

    def from_d( text )
      return described_class.parse_d( text ).map { |token| normalizer.path( token ) }
    end

    def from_markers( text )
      return described_class.parse_markers( text ).map { |literal| normalizer.path( described_class.unescape_c( literal ) ) }
    end

    it 'reads the fixture bytes as the probe printed them' do
      expect( clang_d ).to include( 'src\\drivers\\bar.h' )
      expect( clang_markers.lines[2] ).to eq( "# 1 \".\\\\src/drivers/bar.h\" 1\n" )
      expect( clang_markers.lines[2].count( '\\' ) ).to eq( 2 )
    end

    it 'normalizes clang backslashes in the .d file to the Linux answer' do
      expect( from_d( clang_d ) ).to eq( linux_answer )
    end

    it 'unescapes doubled marker backslashes from clang to the Linux answer' do
      expect( from_markers( clang_markers ) ).to eq( linux_answer )
    end

    it 'normalizes MinGW GCC output, which spells as Linux GCC does, to the Linux answer' do
      expect( from_d( mingw_d ) ).to eq( linux_answer )
      expect( from_markers( mingw_markers ) ).to eq( linux_answer )
    end
  end

end
