# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/generator_partials'
require 'ceedling/partials/partials'
require 'ceedling/includes/includes'
require 'ceedling/c_extractor/c_extractor_types'
require 'stringio'

describe GeneratorPartials do
  before(:each) do
    @file_wrapper    = double( "FileWrapper" )
    @file_path_utils = double( "FilePathUtils" )
    @loginator       = double( "Loginator" ).as_null_object

    @generator = described_class.new(
      {
        :file_wrapper    => @file_wrapper,
        :file_path_utils => @file_path_utils,
        :loginator       => @loginator,
      }
    )
  end

  # Helper to create CVariableDeclaration structs for testing
  def make_var(name:, type:, text:, decorators: [], line_num: nil)
    CExtractorTypes::CVariableDeclaration.new(
      name: name, type: type, decorators: decorators,
      text: text, original: text, line_num: line_num
    )
  end

  # Helper to create CStatement structs for testing
  def make_stmt(text:, line_num: nil)
    CExtractorTypes::CStatement.new(text: text, line_num: line_num)
  end

  # Helper to create a CModule whose element_sequence is exactly `items` (in the given order).
  # The typed arrays are populated from the items for completeness but generation uses element_sequence.
  def make_module(*items)
    vars   = items.select { |i| i.is_a?(CExtractorTypes::CVariableDeclaration) }
    macros = items.select { |i| i.is_a?(CExtractorTypes::CStatement) }
    fdefs  = items.select { |i| i.is_a?(CExtractorTypes::CFunctionDefinition) }
    fdecls = items.select { |i| i.is_a?(CExtractorTypes::CFunctionDeclaration) }
    CExtractorTypes::CModule.new(
      variable_declarations: vars,
      macro_definitions:     macros,
      function_definitions:  fdefs,
      function_declarations: fdecls,
      element_sequence:      items
    )
  end

  # Empty CModule — used when tests only care about function_list or includes
  def empty_module
    CExtractorTypes::CModule.new()
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
          name: 'initialize',
          signature: 'void initialize(void)',
          code_block: "void initialize(void) {\n  // implementation\n}"
        )
      ]
      source_includes = [UserInclude.new('types.h'), UserInclude.new('config.h')]
      header_includes = [SystemInclude.new('stdint.h'), SystemInclude.new('stdbool.h')]
      c_module = make_module(
        make_var(name: 'my_var', type: 'uint8_t', text: 'uint8_t my_var;'),
        make_stmt(text: "#define MAX_SIZE 100\n", line_num: 5)
      )

      # Execute
      result = @generator.generate_implementation(
        test: 'test_my_implementation',
        name: name,
        function_definitions: defns,
        source_includes: source_includes,
        header_includes: header_includes,
        c_module: c_module,
        output_path: output_path
      )

      # Verify generate_header was called with correct parameters
      expect(@generator).to have_received(:generate_header).with(
        header_file_handle,
        header_filename,
        header_includes,
        defns,
        c_module,
        true
      )

      # Verify generate_source was called with correct parameters
      expect(@generator).to have_received(:generate_source).with(
        source_file_handle,
        source_includes,
        defns,
        c_module
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
          name: 'initilalize',
          signature: 'void initialize(void)'
        )
      ]
      includes = [UserInclude.new('types.h'), UserInclude.new('config.h')]
      c_module = make_module(
        make_stmt(text: "typedef uint8_t Byte;\n", line_num: 3)
      )

      # Execute
      result = @generator.generate_interface(
        test: 'test_my_interface',
        function_declarations: decls,
        name: name,
        includes: includes,
        c_module: c_module,
        output_path: output_path
      )

      # Verify generate_header was called with correct parameters
      expect(@generator).to have_received(:generate_header).with(
        file_handle,
        header_filename,
        includes,
        decls,
        c_module,
        false
      )

      # Verify file path utilities were called
      expect(@file_path_utils).to have_received(:form_partial_interface_header_filename).with(name)

      # Verify file operations
      expect(@file_wrapper).to have_received(:open).with(expected_filepath, 'w')

      # Verify return value is the header filepath
      expect(result).to eq(expected_filepath)
    end
  end

  context "#generate_header (private method)" do
    # Define common StringIO buffer
    let(:buf) { StringIO.new() }

    it "should generate a nearly empty header file" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __FOO_BAR_H__
      #define __FOO_BAR_H__

      #endif // __FOO_BAR_H__

      CONTENTS

      @generator.send(:generate_header, buf, 'foo_bar', [], [], empty_module, false)
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

      @generator.send(
        :generate_header,
        buf,
        'Apples-and-Bananas',
        [UserInclude.new('foo.h'), UserInclude.new('bar.h')],
        [], empty_module, false
      )

      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a header file with variable declarations (extern prefix added automatically)" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __PB_AND_J_H__
      #define __PB_AND_J_H__

      extern unsigned int slices_of_bread;
      extern char crumbs;

      #endif // __PB_AND_J_H__

      CONTENTS

      c_module = make_module(
        make_var(name: 'slices_of_bread', type: 'unsigned int', text: 'unsigned int slices_of_bread = 10;'),
        make_var(name: 'crumbs', type: 'char', text: 'char crumbs[10];')
      )
      @generator.send(:generate_header, buf, 'pb-and-j', [], [], c_module, true)
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
        name: 'foobarbaz',
        signature: 'void foobarbaz(int x, int y)'
      )

      decls << Partials.manufacture_function_declaration(
        name: 'razzleDazzle',
        signature: 'int razzleDazzle(void* ptr)'
      )

      # Raw CExtractor stubs for the lookup by name — only :name must match decls
      foobarbaz_raw   = CExtractorTypes::CFunctionDeclaration.new(name: 'foobarbaz')
      razzledazzle_raw = CExtractorTypes::CFunctionDeclaration.new(name: 'razzleDazzle')

      c_module = make_module(
        make_var(name: 'apples', type: 'signed long int', text: 'signed long int apples;'),
        make_var(name: 'bananas', type: 'double', text: 'double bananas;'),
        foobarbaz_raw,
        razzledazzle_raw
      )

      @generator.send(
        :generate_header,
        buf,
        'Apples-and-Bananas',
        [UserInclude.new('Eeny.h'), UserInclude.new('Meeny.h')],
        decls,
        c_module,
        true
      )

      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should emit CStatement text as-is in the header" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __DEFS_H__
      #define __DEFS_H__

      #define MAX_SIZE 100
      typedef uint8_t Byte;
      struct Point { int x; int y; };

      #endif // __DEFS_H__

      CONTENTS

      c_module = make_module(
        make_stmt(text: "#define MAX_SIZE 100"),
        make_stmt(text: "typedef uint8_t Byte;"),
        make_stmt(text: "struct Point { int x; int y; };")
      )

      @generator.send(:generate_header, buf, 'defs', [], [], c_module, false)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should emit all four injectable statement categories correctly in element_sequence order" do
      # One item of each category that can be injected into a generated Partial header:
      #   macro_definitions    → CStatement emitted as-is
      #   type_definitions     → CStatement emitted as-is
      #   aggregate_definitions → CStatement emitted as-is
      #   variable_declarations → CVariableDeclaration emitted as extern declaration
      #
      # Ordering is intentionally interleaved (not grouped by category) to confirm that
      # element_sequence — not typed-array membership — governs emit order.
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __ALL_STATEMENTS_H__
      #define __ALL_STATEMENTS_H__

      #define MAX_ITEMS 16
      typedef uint8_t Byte;
      extern int item_count;
      struct Config { int id; int flags; };

      #endif // __ALL_STATEMENTS_H__

      CONTENTS

      macro_stmt     = CExtractorTypes::CStatement.new(text: "#define MAX_ITEMS 16",              line_num: 1)
      typedef_stmt   = CExtractorTypes::CStatement.new(text: "typedef uint8_t Byte;",             line_num: 2)
      var_decl       = make_var(name: 'item_count', type: 'int', text: 'int item_count;',         line_num: 3)
      aggregate_stmt = CExtractorTypes::CStatement.new(text: "struct Config { int id; int flags; };", line_num: 4)

      c_module = CExtractorTypes::CModule.new(
        macro_definitions:     [macro_stmt],
        type_definitions:      [typedef_stmt],
        aggregate_definitions: [aggregate_stmt],
        variable_declarations: [var_decl],
        element_sequence:      [macro_stmt, typedef_stmt, var_decl, aggregate_stmt]
      )

      @generator.send(:generate_header, buf, 'all_statements', [], [], c_module, true)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should emit mixed CStatement and CVariableDeclaration items in element_sequence order" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __MIXED_H__
      #define __MIXED_H__

      #define FOO 1
      extern int counter;
      typedef uint8_t Byte;

      #endif // __MIXED_H__

      CONTENTS

      # element_sequence dictates the order; line_num is informational only
      c_module = make_module(
        make_stmt(text: "#define FOO 1",      line_num: 1),
        make_var( name: 'counter', type: 'int', text: 'int counter;', line_num: 2),
        make_stmt(text: "typedef uint8_t Byte;", line_num: 3)
      )

      @generator.send(:generate_header, buf, 'mixed', [], [], c_module, true)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should not emit variable declarations when include_variables is false" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __INTERFACE_H__
      #define __INTERFACE_H__

      #define FOO 1

      #endif // __INTERFACE_H__

      CONTENTS

      c_module = make_module(
        make_stmt(text: "#define FOO 1", line_num: 1),
        make_var( name: 'counter', type: 'int', text: 'int counter;', line_num: 2)
      )

      @generator.send(:generate_header, buf, 'interface', [], [], c_module, false)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should interleave functions with other elements in element_sequence order" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #ifndef __INTERLEAVED_H__
      #define __INTERLEAVED_H__

      typedef uint8_t Byte;

      void foo(void);

      extern int counter;

      int bar(int x);

      #endif // __INTERLEAVED_H__

      CONTENTS

      typedef_stmt = make_stmt(text: "typedef uint8_t Byte;", line_num: 1)
      var_decl     = make_var( name: 'counter', type: 'int', text: 'int counter;', line_num: 5)

      foo_raw = CExtractorTypes::CFunctionDeclaration.new(
        name: 'foo', signature: 'void foo(void)', line_num: 3
      )
      bar_raw = CExtractorTypes::CFunctionDeclaration.new(
        name: 'bar', signature: 'int bar(int x)', line_num: 7
      )

      foo_decl = Partials.manufacture_function_declaration(name: 'foo', signature: 'void foo(void)')
      bar_decl = Partials.manufacture_function_declaration(name: 'bar', signature: 'int bar(int x)')

      # element_sequence captures original file order across all types
      c_module = CExtractorTypes::CModule.new(
        variable_declarations: [var_decl],
        function_declarations: [foo_raw, bar_raw],
        type_definitions:      [typedef_stmt],
        element_sequence:      [typedef_stmt, foo_raw, var_decl, bar_raw]
      )

      @generator.send(:generate_header, buf, 'interleaved', [], [foo_decl, bar_decl], c_module, true)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "emits function signature with __declspec(dllexport) verbatim in header" do
      decl = Partials.manufacture_function_declaration(
        name: 'exported_func',
        signature: '__declspec(dllexport) void exported_func(void)'
      )
      raw = CExtractorTypes::CFunctionDeclaration.new(name: 'exported_func')
      c_module = make_module(raw)

      @generator.send(:generate_header, buf, 'mymod', [], [decl], c_module, false)

      expect(buf.string).to include('__declspec(dllexport) void exported_func(void);')
    end

    it "emits extern variable declaration using clean type and name, not raw text with __attribute__" do
      c_module = make_module(
        make_var(name: 'counter', type: 'int', text: 'int counter __attribute__((aligned(16)));')
      )

      @generator.send(:generate_header, buf, 'mymod', [], [], c_module, true)

      expect(buf.string).to include('extern int counter;')
      expect(buf.string).not_to include('__attribute__')
    end

  end

  context "#generate_source (private method)" do
    # Define common StringIO buffer
    let(:buf) { StringIO.new() }

    it "should generate a nearly empty source file" do
      @generator.send(:generate_source, buf, [], [], empty_module)
      expect( buf.string.strip() ).to eq '// Ceeding generated file'
    end

    it "should generate a source file with #include directives" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #include "foo.h"
      #include <bar.h>

      CONTENTS

      @generator.send(
        :generate_source,
        buf,
        [UserInclude.new('foo.h'), SystemInclude.new('bar.h')],
        [], empty_module
      )

      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a source file with (tidied up) functions" do
      file_contents = <<~CONTENTS
      // Ceeding generated file

      void foobar(int x, int y)
      {
        int z = x+y;
      }

      CONTENTS

      defns = []

      defns << Partials.manufacture_function_definition(
        name: 'foobar',
        signature: 'void foobar(int x, int y)',
        code_block: "void foobar(int x, int y)\n\n{\n\n  int z = x+y;\n\n\n}"
      )

      # Raw CExtractor stub for the lookup by name
      c_module = make_module( CExtractorTypes::CFunctionDefinition.new(name: 'foobar') )

      @generator.send(:generate_source, buf, [], defns, c_module)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should generate a source file with include directives, variable declarations, and functions" do
      file_contents = <<~CONTENTS
      // Ceeding generated file
      #include "foobar.h"
      #include "baz.h"

      int abc = 123;
      char str[] = "Hello, World!";

      void foobar(int x, int y) {
        int z = x+y;
      }

      CONTENTS

      defn = Partials.manufacture_function_definition(
        name: 'foobar',
        signature: 'void foobar(int x, int y)',
        code_block: "void foobar(int x, int y) {\n  int z = x+y;\n}"
      )

      var_abc   = make_var(name: 'abc', type: 'int', text: 'int abc = 123;')
      var_str   = make_var(name: 'str', type: 'char', text: 'char str[] = "Hello, World!";')
      # Raw CExtractor stub for the lookup by name
      foobar_raw = CExtractorTypes::CFunctionDefinition.new(name: 'foobar')

      c_module = make_module(var_abc, var_str, foobar_raw)

      @generator.send(
        :generate_source,
        buf,
        [UserInclude.new('foobar.h'), UserInclude.new('baz.h')],
        [defn],
        c_module
      )
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
        name: 'foobarbaz',
        signature: 'void foobarbaz(int x, int y)',
        code_block: "void foobarbaz(int x, int y) {\n  int z = x+y;\n}"
      )

      defns << Partials.manufacture_function_definition(
        line_num: 123,
        source_filepath: 'src/code/ABC.c',
        name: 'razzleDazzle',
        signature: 'int razzleDazzle(void* ptr)',
        code_block: "int\nrazzleDazzle(void* ptr)\n{\n  global_var = ptr;\n  return 42;\n}"
      )

      # Raw CExtractor stubs for the lookup by name — in extraction order
      c_module = make_module(
        CExtractorTypes::CFunctionDefinition.new(name: 'foobarbaz'),
        CExtractorTypes::CFunctionDefinition.new(name: 'razzleDazzle')
      )

      @generator.send(:generate_source, buf, [], defns, c_module)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should emit only variable declarations and function definitions from all four element_sequence categories" do
      # Source generation emits two categories and silently skips two others:
      #   CVariableDeclaration  → emitted as-is
      #   CFunctionDefinition   → emitted (via filtered Partials lookup)
      #   CStatement            → skipped (macros, typedefs, aggregates belong in headers)
      #   CFunctionDeclaration  → skipped (forward declarations belong in headers)
      #
      # All four categories are present in element_sequence to confirm the full
      # filtering and emission behavior in a single test.
      file_contents = <<~CONTENTS
      // Ceeding generated file

      int counter = 0;

      void compute(int x) {
        return x;
      }

      CONTENTS

      macro_stmt  = CExtractorTypes::CStatement.new(text: "#define MAX 100",      line_num: 1)
      var_decl    = make_var(name: 'counter', type: 'int', text: 'int counter = 0;', line_num: 2)
      func_decl   = CExtractorTypes::CFunctionDeclaration.new(name: 'compute',     line_num: 3)
      func_def    = CExtractorTypes::CFunctionDefinition.new( name: 'compute',     line_num: 4)

      c_module = CExtractorTypes::CModule.new(
        macro_definitions:     [macro_stmt],
        variable_declarations: [var_decl],
        function_declarations: [func_decl],
        function_definitions:  [func_def],
        element_sequence:      [macro_stmt, var_decl, func_decl, func_def]
      )

      defn = Partials.manufacture_function_definition(
        name: 'compute',
        signature: 'void compute(int x)',
        code_block: "void compute(int x) {\n  return x;\n}"
      )

      @generator.send(:generate_source, buf, [], [defn], c_module)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should emit only CVariableDeclaration items from element_sequence, skipping CStatement items" do
      file_contents = <<~CONTENTS
      // Ceeding generated file

      int counter = 0;

      CONTENTS

      # Mixed collection: one variable and two CStatements (macro + typedef)
      c_module = make_module(
        make_stmt(text: "#define MAX 100\n", line_num: 1),
        make_var( name: 'counter', type: 'int', text: 'int counter = 0;'),
        make_stmt(text: "typedef uint8_t Byte;\n", line_num: 3)
      )

      @generator.send(:generate_source, buf, [], [], c_module)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "should interleave variables and functions in element_sequence order" do
      file_contents = <<~CONTENTS
      // Ceeding generated file

      int x = 1;

      void foo(void) {
        x++;
      }

      int y = 2;

      void bar(void) {
        y++;
      }

      CONTENTS

      var_x = make_var(name: 'x', type: 'int', text: 'int x = 1;', line_num: 1)
      var_y = make_var(name: 'y', type: 'int', text: 'int y = 2;', line_num: 5)

      foo_raw = CExtractorTypes::CFunctionDefinition.new(
        name: 'foo', signature: 'void foo(void)', line_num: 3,
        code_block: "void foo(void) {\n  x++;\n}", body: "{\n  x++;\n}"
      )
      bar_raw = CExtractorTypes::CFunctionDefinition.new(
        name: 'bar', signature: 'void bar(void)', line_num: 7,
        code_block: "void bar(void) {\n  y++;\n}", body: "{\n  y++;\n}"
      )

      foo_defn = Partials.manufacture_function_definition(
        name: 'foo', signature: 'void foo(void)',
        code_block: "void foo(void) {\n  x++;\n}"
      )
      bar_defn = Partials.manufacture_function_definition(
        name: 'bar', signature: 'void bar(void)',
        code_block: "void bar(void) {\n  y++;\n}"
      )

      c_module = CExtractorTypes::CModule.new(
        variable_declarations: [var_x, var_y],
        function_definitions:  [foo_raw, bar_raw],
        element_sequence:      [var_x, foo_raw, var_y, bar_raw]
      )

      @generator.send(:generate_source, buf, [], [foo_defn, bar_defn], c_module)
      expect( buf.string.strip() ).to eq file_contents.strip()
    end

    it "emits function code_block with __attribute__((noreturn)) verbatim in source" do
      defn = Partials.manufacture_function_definition(
        name: 'fatal_error',
        signature: '__attribute__((noreturn)) void fatal_error(const char* msg)',
        code_block: "__attribute__((noreturn)) void fatal_error(const char* msg)\n{\n  exit(1);\n}"
      )
      raw = CExtractorTypes::CFunctionDefinition.new(
        name: 'fatal_error',
        signature: '__attribute__((noreturn)) void fatal_error(const char* msg)',
        code_block: "__attribute__((noreturn)) void fatal_error(const char* msg)\n{\n  exit(1);\n}",
        body: "{\n  exit(1);\n}"
      )
      c_module = make_module(raw)

      @generator.send(:generate_source, buf, [], [defn], c_module)

      expect(buf.string).to include('__attribute__((noreturn)) void fatal_error(const char* msg)')
      expect(buf.string).to include('exit(1);')
    end

    it "emits variable .text with __attribute__((aligned)) verbatim in source" do
      c_module = make_module(
        make_var(name: 'counter', type: 'int', text: 'int counter __attribute__((aligned(16)));')
      )

      @generator.send(:generate_source, buf, [], [], c_module)

      expect(buf.string).to include('int counter __attribute__((aligned(16)));')
    end

  end

end
