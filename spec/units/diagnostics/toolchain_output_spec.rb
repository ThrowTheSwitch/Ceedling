# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/diagnostics/toolchain_output'

describe ToolchainOutput do
  describe '.headers' do
    {
      'GCC and Clang'                => "src/a.h:12:3: error: redefinition of 'struct s'",
      'GCC include chains'           => "In file included from src/a.h:2,\n                 from test.c:1:",
      'IAR'                          => "\"src/a.h\",12  Error[Pe101]: \"s\" has already been declared",
      'Arm armcc, TI, Green Hills'   => "\"src/a.h\", line 12: error #101: \"s\" has already been declared",
      'MSVC'                         => "src/a.h(12): error C2011: 's': 'struct' type redefinition",
      'EDG declared-at notes'        => "declaration is incompatible (declared at line 5 of \"src/a.h\")",
      'quoted in prose'              => "previous definition of 'x' in 'src/a.h' was here",
      'backquoted'                   => "`src/a.h' line 3"
    }.each do |family, output|
      it "reads a header path in #{family} output" do
        expect( described_class.headers( output ) ).to eq( ['src/a.h'] )
      end
    end

    it 'reads C++ header extensions' do
      expect( described_class.headers( 'a.hh:1:1 b.hpp:1:1 c.hxx(1)' ) ).to eq( ['a.hh', 'b.hpp', 'c.hxx'] )
    end

    it 'reads Windows paths, drive letter and backslashes included' do
      expect( described_class.headers( "C:\\proj\\inc\\a.h(12): error C2011" ) ).to eq( ["C:\\proj\\inc\\a.h"] )
      expect( described_class.headers( "\"C:\\proj\\inc\\a.h\",12  Error[Pe101]" ) ).to eq( ["C:\\proj\\inc\\a.h"] )
    end

    it 'reads paths with spaces only when quoted' do
      expect( described_class.headers( '"my dir/a.h", line 3: error' ) ).to eq( ['my dir/a.h'] )
    end

    it 'lists each header once, in order of first mention' do
      expect( described_class.headers( "b.h:1:1 a.h:2:2\nb.h:3:3" ) ).to eq( ['b.h', 'a.h'] )
    end

    it 'ignores a source file and a word that only starts like a header' do
      expect( described_class.headers( 'test.c:1:1: in a.html and x.hint' ) ).to eq( [] )
    end

    it 'reads nothing from missing output' do
      expect( described_class.headers( nil ) ).to eq( [] )
    end

    it 'reads a megabyte-long token in linear time' do
      started = Process.clock_gettime( Process::CLOCK_MONOTONIC )
      expect( described_class.headers( 'a' * 1_000_000 ) ).to eq( [] )
      expect( Process.clock_gettime( Process::CLOCK_MONOTONIC ) - started ).to be < 1.0
    end
  end

  describe '.objects' do
    it 'reads object paths with the given extension in every location format' do
      output = "/usr/bin/ld: build/out/gpio.o: in function `f':\n" \
               "multiple definition of `f'; build/out/mock_gpio.o:(.text+0x0): first defined here\n" \
               "\"build/out/x.o\" and build\\out\\y.o"

      expect( described_class.objects( output, extension: '.o' ) ).to eq(
        ['build/out/gpio.o', 'build/out/mock_gpio.o', 'build/out/x.o', "build\\out\\y.o"]
      )
    end

    it 'reads an Arm armlink object list' do
      output = 'Error: L6200E: Symbol f multiply defined (by mock_gpio.o and gpio.o).'

      expect( described_class.objects( output, extension: '.o' ) ).to eq( ['mock_gpio.o', 'gpio.o'] )
    end

    it 'honors another object extension' do
      expect( described_class.objects( 'LNK2005: f already defined in gpio.obj', extension: '.obj' ) ).to eq( ['gpio.obj'] )
      expect( described_class.objects( 'gpio.o and gpio.obj', extension: '.obj' ) ).to eq( ['gpio.obj'] )
    end

    it 'reads nothing from missing output' do
      expect( described_class.objects( nil, extension: '.o' ) ).to eq( [] )
    end
  end
end
