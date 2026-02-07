# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generator_partials'
require 'ceedling/partials'
require 'stringio'

describe GeneratorPartials do
  before(:each) do
    @file_wrapper = double( "FileWrapper" )
    @file_path_utils = double( "FilePathUtils" )

    @generator = described_class.new(
      {
        :file_wrapper => @file_wrapper,
        :file_path_utils => @file_path_utils,
      }
    )
  end

  context "#generate_implementation" do
    it "should call generate_header() and generate_source() with correct parameters" do
      # Setup
      output_path = '/path/to/output'
      name = 'my_implementation'
      source_filename = 'my_implementation_impl.c'
      header_filename = 'my_implementation_impl.h'
      expected_source_filepath = File.join(output_path, source_filename)
      expected_header_filepath = File.join(output_path, header_filename)
      
      # Mock FilePathUtils
      allow(@file_path_utils).to receive(:form_partial_implementation_source_filename)
        .with(name)
        .and_return(source_filename)
      
      allow(@file_path_utils).to receive(:form_partial_implementation_header_filename)
        .with(name)
        .and_return(header_filename)
      
      # Mock FileWrapper.open to yield file handles
      header_file_handle = double('header_file_handle')
      source_file_handle = double('source_file_handle')
      
      allow(@file_wrapper).to receive(:open)
        .with(expected_header_filepath, 'w')
        .and_yield(header_file_handle)
      
      allow(@file_wrapper).to receive(:open)
        .with(expected_source_filepath, 'w')
        .and_yield(source_file_handle)
      
      # Spy on generate_header and generate_source -- allow them to be called but track the calls
      allow(@generator).to receive(:generate_header)
      allow(@generator).to receive(:generate_source)
      
      # Define test data
      defns = [
        Partials.manufacture_function_definition(
          signature: 'void initialize(void)',
          code_block: "void initialize(void) {\n  // implementation\n}"
        )
      ]
      source_includes = ['types.h', 'config.h']
      header_includes = ['stdint.h', 'stdbool.h']
      header_variables = ['extern uint8_t my_var;']
      
      # Execute
      result = @generator.generate_implementation(
        definitions: defns,
        header_variables: header_variables,
        name: name,
        source_includes: source_includes,
        header_includes: header_includes,
        output_path: output_path
      )
      
      # Verify generate_header was called with correct parameters
      expect(@generator).to have_received(:generate_header).with(
        header_file_handle,
        header_filename,
        header_includes,
        defns,
        header_variables
      )
      
      # Verify generate_source was called with correct parameters
      expect(@generator).to have_received(:generate_source).with(
        source_file_handle,
        source_includes,
        defns
      )
      
      # Verify file path utilities were called
      expect(@file_path_utils).to have_received(:form_partial_implementation_source_filename).with(name)
      expect(@file_path_utils).to have_received(:form_partial_implementation_header_filename).with(name)
      
      # Verify file operations
      expect(@file_wrapper).to have_received(:open).with(expected_header_filepath, 'w')
      expect(@file_wrapper).to have_received(:open).with(expected_source_filepath, 'w')
      
      # Verify return value is the source filepath
      expect(result).to eq(expected_source_filepath)
    end
  end

  context "#generate_interface" do
    it "should call generate_header() with correct parameters" do
      # Setup
      output_path = '/path/to/output'
      name = 'my_interface'
      header_filename = 'my_interface_interface.h'
      expected_filepath = File.join(output_path, header_filename)
      
      # Mock FilePathUtils
      allow(@file_path_utils).to receive(:form_partial_interface_header_filename)
        .with(name)
        .and_return(header_filename)
      
      # Mock FileWrapper.open to yield a file handle
      file_handle = double('file_handle')
      allow(@file_wrapper).to receive(:open)
        .with(expected_filepath, 'w')
        .and_yield(file_handle)
      
      # Spy on generate_header -- allow it to be called but track the call
      allow(@generator).to receive(:generate_header)
      
      # Define test data
      decls = [
        Partials.manufacture_function_declaration(
          signature: 'void initialize(void)'
        )
      ]
      includes = ['types.h', 'config.h']
      
      # Execute
      result = @generator.generate_interface(
        declarations: decls,
        name: name,
        includes: includes,
        output_path: output_path
      )
      
      # Verify generate_header was called with correct parameters
      expect(@generator).to have_received(:generate_header).with(
        file_handle,
        header_filename,
        includes,
        decls,
        []
      )
      
      # Verify file path utilities were called
      expect(@file_path_utils).to have_received(:form_partial_interface_header_filename).with(name)
      
      # Verify file operations
      expect(@file_wrapper).to have_received(:open).with(expected_filepath, 'w')
      
      # Verify return value is the header filepath
      expect(result).to eq(expected_filepath)
    end
  end

  context "#generate_header" do
    # Define common StringIO buffer
    let(:buf) { StringIO.new() }

    it "should generate a nearly empty header file" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __FOO_BAR_H__
      #define __FOO_BAR_H__

      #endif // __FOO_BAR_H__
    
      CONTENTS

      @generator.generate_header(buf, 'foo_bar', [], [], [])
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a header file with #include statements but nothing else" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __APPLES_AND_BANANAS_H__
      #define __APPLES_AND_BANANAS_H__

      #include "foo.h"
      #include "bar.h"

      #endif // __APPLES_AND_BANANAS_H__
    
      CONTENTS

      @generator.generate_header(buf, 'Apples-and-Bananas', ['foo.h', 'bar.h'], [], [])
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a header file with variable declarations but nothing else" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __PB_AND_J_H__
      #define __PB_AND_J_H__

      extern unsigned int slices_of_bread;
      extern char[10] crumbs;

      #endif // __PB_AND_J_H__
    
      CONTENTS

      variables = [
        'extern unsigned int slices_of_bread;',
        'extern char[10] crumbs;'
      ]
      @generator.generate_header(buf, 'pb-and-j', [], [], variables)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a header file with #include statements, variable declarations, and function signatures" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __APPLES_AND_BANANAS_H__
      #define __APPLES_AND_BANANAS_H__

      #include "Eeny.h"
      #include "Meeny.h"

      extern signed long int apples;
      extern double bananas;

      void foobarbaz(int x, int y);

      int razzleDazzle(void* ptr);

      #endif // __APPLES_AND_BANANAS_H__
    
      CONTENTS

      decls = []

      decls << Partials.manufacture_function_declaration(
        signature: 'void foobarbaz(int x, int y)'
      )

      decls << Partials.manufacture_function_declaration(
        signature: 'int razzleDazzle(void* ptr)'
      )

      variables = [
        'extern signed long int apples;',
        'extern double bananas;'
      ]

      @generator.generate_header(buf, 'Apples-and-Bananas', ['Eeny.h', 'Meeny.h'], decls, variables)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

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

      void foobar(int x, int y) {
        int z = x+y;
      }

      CONTENTS

      defns = []

      defns << Partials.manufacture_function_definition(
        signature: 'void foobar(int x, int y)',
        code_block: "void foobar(int x, int y) {\n  int z = x+y;\n}"
      )

      @generator.generate_source(buf, [], defns)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a source file with functions and #line directives" do
      file_contents = <<~CONTENTS
      // Ceeding generated file

      #line 9 "../foo/bar/fubar.c"
      void foobarbaz(int x, int y) {
        int z = x+y;
      }

      #line 123 "src/code/ABC.c"
      int
      razzleDazzle(void* ptr)
      {
        global_var = ptr;
        return 42;
      }

      CONTENTS

      defns = []

      defns << Partials.manufacture_function_definition(
        line_num: 9,
        source_filepath: '../foo/bar/fubar.c',
        signature: 'void foobarbaz(int x, int y)',
        code_block: "void foobarbaz(int x, int y) {\n  int z = x+y;\n}"
      )

      defns << Partials.manufacture_function_definition(
        line_num: 123,
        source_filepath: 'src/code/ABC.c',
        signature: 'int razzleDazzle(void* ptr)',
        code_block: "int\nrazzleDazzle(void* ptr)\n{\n  global_var = ptr;\n  return 42;\n}"
      )

      @generator.generate_source(buf, [], defns)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end


  end

end
