# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generator_partial_implementation'
require 'stringio'

describe GeneratorPartialImplementation do
  before(:each) do
    @file_wrapper = double( "FileWrapper" ) # Not actually exercised in these test cases

    @generator = described_class.new(
      {
        :file_wrapper => @file_wrapper,
      }
    )
  end

  context "#generate_source" do
    # Define common StringIO buffer
    let(:buf) { StringIO.new() }

    it "should generate a nearly empty source file" do
      @generator.generate_source(buf, [], [])
      expect( buf.string.strip() ).to eq '// Ceeding generated file'
    end

    it "should generate a source file with #include directives" do
      file_contents = <<~CONTENTS
      // Ceeding generated file

      #include "foo.h"
      #include "bar.h"

      CONTENTS

      @generator.generate_source(buf, ['foo.h', 'bar.h'], [])
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a source file with functions" do
      file_contents = <<~CONTENTS
      // Ceeding generated file

      
      #line 9 "../foo/bar/fubar.c"
      void foobar(int x, int y) {
        int z = x+y;
      }

      CONTENTS

      funcs = []

      funcs << @generator.manufacture_function_struct(
        line_num: 9,
        source_filepath: '../foo/bar/fubar.c',
        signature: 'void foobar(int x, int y)',
        code_block: "void foobar(int x, int y) {\n  int z = x+y;\n}"
      )

      @generator.generate_source(buf, [], funcs)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end


  end

end
