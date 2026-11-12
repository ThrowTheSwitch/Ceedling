
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'spec_helper'
require 'timeout'
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partializer_utils'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ostruct'

describe PartializerHelper do
  before(:each) do
    @partializer_utils        = double("PartializerUtils")
    @c_extractor              = double("CExtractor")
    @c_extractor_declarations = double("CExtractorDeclarations")
    @file_path_utils          = double("FilePathUtils")
    @parsing_parcels          = ParsingParcels.new
    @loginator                = double("Loginator").as_null_object

    @helper = described_class.new(
      {
        :partializer_utils        => @partializer_utils,
        :c_extractor              => @c_extractor,
        :c_extractor_declarations => @c_extractor_declarations,
        :file_path_utils          => @file_path_utils,
        :parsing_parcels          => @parsing_parcels,
        :loginator                => @loginator
      }
    )
  end

  context "#filter_and_transform_funcs" do
    before(:each) do
      @mock_func1 = double('func1',
        name:               'publicFunc',
        decorators:         [],
        signature_stripped: 'void publicFunc(void)'
      )
      @mock_func2 = double('func2',
        name:               'staticFunc',
        decorators:         ['static'],
        signature_stripped: 'void staticFunc(void)'
      )
      @mock_func3 = double('func3',
        name:               'inlineFunc',
        decorators:         ['inline'],
        signature_stripped: 'int inlineFunc(int x)'
      )
    end

    it "returns empty array when functions list is empty" do
      result = @helper.filter_and_transform_funcs([], Partials::PUBLIC, :impl)
      expect(result).to eq([])
    end

    it "filters out public function when :private visibility requested" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PRIVATE)
        .and_return(false)

      result = @helper.filter_and_transform_funcs([@mock_func1], Partials::PRIVATE, :impl)
      expect(result).to eq([])
    end

    it "filters out private function when :public visibility requested" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], Partials::PUBLIC)
        .and_return(false)

      result = @helper.filter_and_transform_funcs([@mock_func2], Partials::PUBLIC, :impl)
      expect(result).to eq([])
    end

    it "transforms a matching public function to :impl type" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PUBLIC)
        .and_return(true)

      mock_impl = double('FunctionDefinition')
      expect(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_impl)

      result = @helper.filter_and_transform_funcs([@mock_func1], Partials::PUBLIC, :impl)
      expect(result).to eq([mock_impl])
    end

    it "transforms a matching public function to :interface type" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PUBLIC)
        .and_return(true)

      mock_interface = double('FunctionDeclaration')
      expect(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :interface)
        .and_return(mock_interface)

      result = @helper.filter_and_transform_funcs([@mock_func1], Partials::PUBLIC, :interface)
      expect(result).to eq([mock_interface])
    end

    it "returns only the matching function when mixed public/private present" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PUBLIC)
        .and_return(true)
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], Partials::PUBLIC)
        .and_return(false)

      mock_transformed = double('transformed_func')
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_transformed)

      result = @helper.filter_and_transform_funcs([@mock_func1, @mock_func2], Partials::PUBLIC, :impl)
      expect(result).to eq([mock_transformed])
    end

    it "filters to only the private function when :private visibility requested" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PRIVATE)
        .and_return(false)
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], Partials::PRIVATE)
        .and_return(true)

      mock_transformed = double('transformed_func')
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func2, 'void staticFunc(void)', :impl)
        .and_return(mock_transformed)

      result = @helper.filter_and_transform_funcs([@mock_func1, @mock_func2], Partials::PRIVATE, :impl)
      expect(result).to eq([mock_transformed])
    end

    it "processes multiple matching functions preserving order" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PUBLIC)
        .and_return(true)
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['static'], Partials::PUBLIC)
        .and_return(false)
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(['inline'], Partials::PUBLIC)
        .and_return(true)

      mock_result1 = double('result1')
      mock_result3 = double('result3')

      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func1, 'void publicFunc(void)', :impl)
        .and_return(mock_result1)
      allow(@partializer_utils).to receive(:transform_function)
        .with(@mock_func3, 'int inlineFunc(int x)', :impl)
        .and_return(mock_result3)

      result = @helper.filter_and_transform_funcs([@mock_func1, @mock_func2, @mock_func3], Partials::PUBLIC, :impl)
      expect(result).to eq([mock_result1, mock_result3])
    end

    it "returns empty array when no functions match visibility" do
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with([], Partials::PRIVATE)
        .and_return(false)

      result = @helper.filter_and_transform_funcs([@mock_func1], Partials::PRIVATE, :impl)
      expect(result).to eq([])
    end
  end

  context "#find_and_transform_func" do
    before(:each) do
      @prim_func = OpenStruct.new(name: 'primary_func', signature_stripped: 'int primary_func(void)')
      @sec_func  = OpenStruct.new(name: 'secondary_func', signature_stripped: 'void secondary_func(void)')
      @transformed = double('transformed')
    end

    it "returns transformed result from primary_funcs when found there" do
      expect(@partializer_utils).to receive(:transform_function)
        .with(@prim_func, 'int primary_func(void)', :impl)
        .and_return(@transformed)

      result = @helper.find_and_transform_func(
        name:            'primary_func',
        primary_funcs:   [@prim_func],
        secondary_funcs: [@sec_func],
        output_type:     :impl
      )
      expect(result).to eq(@transformed)
    end

    it "falls back to secondary_funcs when name not in primary" do
      expect(@partializer_utils).to receive(:transform_function)
        .with(@sec_func, 'void secondary_func(void)', :interface)
        .and_return(@transformed)

      result = @helper.find_and_transform_func(
        name:            'secondary_func',
        primary_funcs:   [@prim_func],
        secondary_funcs: [@sec_func],
        output_type:     :interface
      )
      expect(result).to eq(@transformed)
    end

    it "returns nil when name not found in either list" do
      expect(@partializer_utils).not_to receive(:transform_function)

      result = @helper.find_and_transform_func(
        name:            'missing',
        primary_funcs:   [@prim_func],
        secondary_funcs: [@sec_func],
        output_type:     :impl
      )
      expect(result).to be_nil
    end

    it "does not search secondary when name found in primary" do
      expect(@partializer_utils).to receive(:transform_function)
        .with(@prim_func, 'int primary_func(void)', :interface)
        .and_return(@transformed)
        .once

      # A duplicate of prim_func in secondary — should never be reached
      sec_dup = OpenStruct.new(name: 'primary_func', signature_stripped: 'WRONG')

      result = @helper.find_and_transform_func(
        name:            'primary_func',
        primary_funcs:   [@prim_func],
        secondary_funcs: [sec_dup],
        output_type:     :interface
      )
      expect(result).to eq(@transformed)
    end
  end

  context "#subtract_funcs" do
    before(:each) do
      @fa = OpenStruct.new(name: 'foo')
      @fb = OpenStruct.new(name: 'bar')
      @fc = OpenStruct.new(name: 'baz')
    end

    it "removes a named function from the list" do
      result = @helper.subtract_funcs(funcs: [@fa, @fb, @fc], names: ['bar'])
      expect(result.map(&:name)).to eq(['foo', 'baz'])
    end

    it "removes multiple named functions" do
      result = @helper.subtract_funcs(funcs: [@fa, @fb, @fc], names: ['foo', 'baz'])
      expect(result.map(&:name)).to eq(['bar'])
    end

    it "returns original list unchanged when names is empty" do
      result = @helper.subtract_funcs(funcs: [@fa, @fb], names: [])
      expect(result).to eq([@fa, @fb])
    end

    it "has no effect when named function is not in the list" do
      result = @helper.subtract_funcs(funcs: [@fa, @fb], names: ['nonexistent'])
      expect(result.map(&:name)).to eq(['foo', 'bar'])
    end

    it "returns empty array when all functions are subtracted" do
      result = @helper.subtract_funcs(funcs: [@fa, @fb], names: ['foo', 'bar'])
      expect(result).to eq([])
    end
  end

  context "#associate_function_line_numbers" do
    before(:each) do
      @name                 = 'TestModule'
      @filepath             = '/path/to/module.c'
      @preprocessed_filepath = '/build/preproc/module_TestModule.i'

      allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(@preprocessed_filepath)

      allow(@partializer_utils).to receive(:stamp_source_filepaths)
      allow(@partializer_utils).to receive(:format_line_number_list).and_return([])
      allow(@partializer_utils).to receive(:locate_functions_in_source).and_return([])
      allow(@partializer_utils).to receive(:locate_functions_via_preprocessed).and_return([])
    end

    it "calls stamp_source_filepaths for empty funcs with fallback: false" do
      expect(@partializer_utils).to receive(:stamp_source_filepaths).with([], @filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "calls stamp_source_filepaths for empty funcs with fallback: true" do
      expect(@partializer_utils).to receive(:stamp_source_filepaths).with([], @filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: true)
    end

    it "constructs preprocessed filepath from name and filepath" do
      expect(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(@preprocessed_filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    # The file is read once for all of its functions
    it "locates every function in the source with one call when fallback: true" do
      func1 = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)
      func2 = OpenStruct.new(code_block: 'int bar(int x) {}', line_num: nil)

      expect(@partializer_utils).to receive(:locate_functions_in_source)
        .with(code_blocks: [func1.code_block, func2.code_block], filepath: @filepath).once
        .and_return([10, 25])

      @helper.associate_function_line_numbers(name: @name, funcs: [func1, func2], filepath: @filepath, fallback: true)

      expect(func1.line_num).to eq(10)
      expect(func2.line_num).to eq(25)
    end

    it "locates every function in the preprocessed copy with one call when fallback: false" do
      func1 = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)
      func2 = OpenStruct.new(code_block: 'int bar(int x) {}', line_num: nil)

      expect(@partializer_utils).to receive(:locate_functions_via_preprocessed)
        .with(code_blocks: [func1.code_block, func2.code_block], filepath: @filepath, preprocessed_filepath: @preprocessed_filepath).once
        .and_return([10, 25])

      @helper.associate_function_line_numbers(name: @name, funcs: [func1, func2], filepath: @filepath, fallback: false)

      expect(func1.line_num).to eq(10)
      expect(func2.line_num).to eq(25)
    end

    it "sets line_num to nil for a function that isn't found" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      allow(@partializer_utils).to receive(:locate_functions_via_preprocessed).and_return([nil])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)

      expect(func.line_num).to be_nil
    end

    it "does not search the preprocessed copy when fallback: true" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      expect(@partializer_utils).not_to receive(:locate_functions_via_preprocessed)
      allow(@partializer_utils).to receive(:locate_functions_in_source).and_return([1])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: true)
    end

    it "does not search the source alone when fallback: false" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      expect(@partializer_utils).not_to receive(:locate_functions_in_source)
      allow(@partializer_utils).to receive(:locate_functions_via_preprocessed).and_return([1])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end

    it "calls format_line_number_list with funcs and passes result to loginator" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil, name: 'foo')

      allow(@partializer_utils).to receive(:locate_functions_via_preprocessed).and_return([5])

      expect(@partializer_utils).to receive(:format_line_number_list).with([func]).and_return(["foo(): 5"])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end

    it "forwards the constructed preprocessed_filepath to locate_functions_via_preprocessed" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      custom_preproc = '/custom/preproc/output.i'
      allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(custom_preproc)

      expect(@partializer_utils).to receive(:locate_functions_via_preprocessed)
        .with(hash_including(preprocessed_filepath: custom_preproc))
        .and_return([nil])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end
  end

  # Carrying reads the names kept code uses. GCC and Clang accept '$' in one.
  context "#_statement_references" do
    it "reads names holding '$', past members and tags" do
      expect( @helper._statement_references( "x$1 = h$2( s.m$3, (struct t$4 *)p$5 );" ).to_a ).to contain_exactly( 'x$1', 'h$2', 's', 'p$5' )
    end
  end

  # A body's own locals shadow a helper of the same name, so they don't count as uses
  context "#_locals" do
    it "reads locals whose names hold '$'" do
      expect( @helper._locals( "{ int h$ = 1; int *q$; struct s$t v; int k; }" ) ).to include( 'h$', 'q$', 'v', 'k' )
    end
  end

  context "#extract_function_scope_static_vars" do
    context "mock-based delegation tests" do
      it "returns empty array and makes no calls when funcs is empty" do
        expect(@c_extractor_declarations).not_to receive(:try_extract_variable)

        result = @helper.extract_function_scope_static_vars([], name: 'test', module_name: 'mod', file_type: 'source')
        expect(result).to eq([])
      end

      it "returns empty array when function body has no declarations (scanner returns false immediately)" do
        func = OpenStruct.new(
          name: 'simple',
          code_block: 'void simple(void) { return; }',
          body: '{ return; }'
        )

        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([false, nil])

        result = @helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')
        expect(result).to eq([])
        expect(func.code_block).to eq('void simple(void) { return; }')
      end

      it "returns empty array when variable is found but is non-static" do
        func = OpenStruct.new(
          name: 'simple',
          code_block: 'void simple(void) { int x; return x; }',
          body: '{ int x; return x; }'
        )

        non_static_var = OpenStruct.new(
          original:    'int x',
          name:        'x',
          decorators:  [],
          text: 'int x;'
        )

        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([true, [non_static_var]], [false, nil])

        result = @helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')
        expect(result).to eq([])
        expect(func.code_block).to eq('void simple(void) { int x; return x; }')
      end

    end

    context "end-to-end happy day tests" do
      let(:real_utils) do
        PartializerUtils.new(
          {
            :preprocessinator_code_finder => double("CodeFinder"),
            :loginator                    => double("Loginator").as_null_object
          }
        )
      end

      let(:real_helper) do
        PartializerHelper.new(
          {
            :partializer_utils        => real_utils,
            :c_extractor              => double("CExtractor").as_null_object,
            :c_extractor_declarations => CExtractorDeclarations.new({ c_extractor_code_text: CExtractorCodeText.new() }).tap(&:setup),
            :file_path_utils          => double("FilePathUtils"),
            :parsing_parcels          => ParsingParcels.new,
            :loginator                => double("Loginator").as_null_object
          }
        )
      end

      it "excises a single static variable declaration and renames references" do
        func = OpenStruct.new(
          name:       'process',
          body:       "{\n  static int count;\n  return count;\n}",
          code_block: "void process(void) {\n  static int count;\n  return count;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        # One var returned with renamed identifier
        expect(result.length).to eq(1)
        expect(result.first.name).to eq('partial_process_count')

        # No-op placeholder present in code_block
        expect(func.code_block).to include('(void)0;')

        # References renamed throughout code_block
        expect(func.code_block).to include('partial_process_count')

        # Original declaration text preserved inside comment
        expect(func.code_block).to include('static int count')
      end

      # A function pointer's declarator wraps its name, so the new name has to reach it too
      it "promotes a function-scope static function pointer under its new name, declarator and all" do
        func = OpenStruct.new(
          name:       'fire',
          body:       "{\n  static int (*cache)(int) = 0;\n  return cache(1);\n}",
          code_block: "int fire(void) {\n  static int (*cache)(int) = 0;\n  return cache(1);\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.type, v.declarator] }).to eq [['partial_fire_cache', 'int', '(*partial_fire_cache)(int)']]
        expect(result.first.text).to include('(*partial_fire_cache)(int)')
        expect(func.code_block).to include('return partial_fire_cache(1);')
      end

      it "promotes a function-scope static function pointer whose name sits in redundant parentheses" do
        func = OpenStruct.new(
          name:       'fire',
          body:       "{\n  static int (*(cache))(int) = 0;\n  return cache(1);\n}",
          code_block: "int fire(void) {\n  static int (*(cache))(int) = 0;\n  return cache(1);\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.declarator] }).to eq [['partial_fire_cache', '(*(partial_fire_cache))(int)']]
      end

      # A macro may declare a static whole, and one the extractor reads no name from stays in place
      it "leaves a function-scope static it can't name in the body" do
        func = OpenStruct.new(
          name:       'tally',
          body:       "{\n  static ARR_OF(int, hits)[3];\n  static int n;\n  return n;\n}",
          code_block: "int tally(void) {\n  static ARR_OF(int, hits)[3];\n  static int n;\n  return n;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map(&:name)).to eq ['partial_tally_n']
        expect(func.code_block).to include('static ARR_OF(int, hits)[3];')
      end

      # Renaming part of a statement would leave the rest of it unpromoted, so the whole one stays
      it "leaves a compound static whole when it can't name one of its variables" do
        func = OpenStruct.new(
          name:       'tally',
          body:       "{\n  static ARR_OF(int, hits)[3], n;\n  static int m;\n  return n + m;\n}",
          code_block: "int tally(void) {\n  static ARR_OF(int, hits)[3], n;\n  static int m;\n  return n + m;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map(&:name)).to eq ['partial_tally_m']
        expect(func.code_block).to include('static ARR_OF(int, hits)[3], n;', 'return n + partial_tally_m;')
      end

      it "promotes each function pointer of a compound static and an array of them" do
        func = OpenStruct.new(
          name:       'fire',
          body:       "{\n  static int (*a)(int), (*b)(int);\n  static int (*t[2])(int) = { 0 };\n  return a(1) + b(2) + t[0](3);\n}",
          code_block: "int fire(void) {\n  static int (*a)(int), (*b)(int);\n  static int (*t[2])(int) = { 0 };\n  return a(1) + b(2) + t[0](3);\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.declarator] }).to eq [
          ['partial_fire_a', '(*partial_fire_a)(int)'],
          ['partial_fire_b', '(*partial_fire_b)(int)'],
          ['partial_fire_t', '(*partial_fire_t[2])(int)']
        ]
        expect(func.code_block).to include('return partial_fire_a(1) + partial_fire_b(2) + partial_fire_t[0](3);')
      end

      it "does not modify code_block when function body has only non-static variables" do
        original_code_block = "void simple(void) {\n  int x = 0;\n  return x;\n}"

        func = OpenStruct.new(
          name:       'simple',
          body:       "{\n  int x = 0;\n  return x;\n}",
          code_block: original_code_block.dup
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result).to eq([])
        expect(func.code_block).to eq(original_code_block)
      end

      it "returns empty array when function has no variable declarations at all" do
        func = OpenStruct.new(
          name:       'empty_func',
          body:       "{\n  return;\n}",
          code_block: "void empty_func(void) {\n  return;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')
        expect(result).to eq([])
      end

      it "correctly handles a compound static declaration without corrupting comments" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int a, b;\n  a = 0;\n  b = 1;\n}",
          code_block: "void calc(void) {\n  static int a, b;\n  a = 0;\n  b = 1;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        # Two vars returned, both renamed
        expect(result.length).to eq(2)
        expect(result.map(&:name)).to contain_exactly('partial_calc_a', 'partial_calc_b')

        # Exactly two no-ops replace the one compound declaration
        expect(func.code_block.scan('(void)0;').length).to eq(2)

        # Renamed references present in code_block
        expect(func.code_block).to include('partial_calc_a')
        expect(func.code_block).to include('partial_calc_b')

        # Replacement no-op with (incomplete) comment
        expect(func.code_block).to include('(void)0; (void)0; /* `static int a, b;` replaced with no-op')
      end

      it "promotes each variable of a compound static whose first one has an initializer" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int x = 0, y;\n  y++;\n  return x + y;\n}",
          code_block: "int calc(void) {\n  static int x = 0, y;\n  y++;\n  return x + y;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.text] }).to eq [['partial_calc_x', 'int partial_calc_x = 0;'], ['partial_calc_y', 'int partial_calc_y;']]
        expect(func.code_block.scan('(void)0;').length).to eq(2)
        expect(func.code_block).to include('return partial_calc_x + partial_calc_y;')
      end

      # One declarator's initializer can name another variable of the same statement
      it "renames every variable of a compound static in each one's text" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int a = 1, *p = &a;\n  return *p;\n}",
          code_block: "int calc(void) {\n  static int a = 1, *p = &a;\n  return *p;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.text] }).to eq [['partial_calc_a', 'int partial_calc_a = 1;'], ['partial_calc_p', 'int *partial_calc_p = &partial_calc_a;']]
      end

      it "renames a promoted static named in another one's array size" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int n = 4, m[sizeof(n)];\n  return m[0];\n}",
          code_block: "int calc(void) {\n  static int n = 4, m[sizeof(n)];\n  return m[0];\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.array_suffix] }).to eq [['partial_calc_n', ''], ['partial_calc_m', '[sizeof(partial_calc_n)]']]
      end

      # A static's initializer can name one an earlier statement declares
      it "renames a promoted static named by a later statement" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int a = 1;\n  static int *p = &a;\n  return *p;\n}",
          code_block: "int calc(void) {\n  static int a = 1;\n  static int *p = &a;\n  return *p;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.text] }).to eq [['partial_calc_a', 'int partial_calc_a = 1;'], ['partial_calc_p', 'int *partial_calc_p = &partial_calc_a;']]
        expect(func.code_block.scan('(void)0;').length).to eq(2)
        expect(func.code_block).to include('return *partial_calc_p;')
      end

      # Under fallback preprocessing a code block keeps its comments, while the body blanks them
      it "promotes a static whose statement holds comments" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int x   = 0;\n  static int a,  b;\n  return x + a + b;\n}",
          code_block: "int calc(void) {\n  static int x /* count */ = 0;\n  static int a, // first\n    b;\n  return x + a + b;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map(&:name)).to eq ['partial_calc_x', 'partial_calc_a', 'partial_calc_b']
        expect(func.code_block.scan('(void)0;').length).to eq(3)
        expect(func.code_block).not_to match(/^\s*static int/)
        expect(func.code_block).to include('return partial_calc_x + partial_calc_a + partial_calc_b;')
      end

      it "promotes a static whose name holds '$'" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int c$1 = 0;\n  int c = c$1;\n  return c$1 + c;\n}",
          code_block: "int calc(void) {\n  static int c$1 = 0;\n  int c = c$1;\n  return c$1 + c;\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.text] }).to eq [['partial_calc_c$1', 'int partial_calc_c$1 = 0;']]
        expect(func.code_block).to include('int c = partial_calc_c$1;', 'return partial_calc_c$1 + c;')
      end

      # A tag lives apart from variables, so a static's type keeps a tag another static shares
      it "leaves a struct tag alone when another promoted static shares its name" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static int node = 0;\n  static struct node *head = 0;\n  return node + (head == 0);\n}",
          code_block: "int calc(void) {\n  static int node = 0;\n  static struct node *head = 0;\n  return node + (head == 0);\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map { |v| [v.name, v.type, v.text] }).to eq [
          ['partial_calc_node', 'int', 'int partial_calc_node = 0;'],
          ['partial_calc_head', 'struct node *', 'struct node *partial_calc_head = 0;']
        ]
      end

      it "leaves a string literal alone when it renames a promoted static" do
        func = OpenStruct.new(
          name:       'calc',
          body:       "{\n  static const char *a = \"x\", *b = \"a b\";\n  printf(\"a=%s\", a);\n  return b[0];\n}",
          code_block: "int calc(void) {\n  static const char *a = \"x\", *b = \"a b\";\n  printf(\"a=%s\", a);\n  return b[0];\n}"
        )

        result = real_helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(result.map(&:text)).to eq ['char *partial_calc_a = "x";', 'char *partial_calc_b = "a b";']
        expect(func.code_block).to include('printf("a=%s", partial_calc_a);')
      end
    end
  end

  ###
  ### Validation helpers shared fixtures
  ###

  def make_func(name, decorators: [])
    OpenStruct.new(name: name, decorators: decorators)
  end

  def make_c_module(funcs)
    OpenStruct.new(function_definitions: funcs)
  end

  def make_pf(type: nil, additions: [], subtractions: [])
    OpenStruct.new(type: type, additions: additions, subtractions: subtractions)
  end

  def make_config(mod, tests:, mocks:)
    OpenStruct.new(module: mod, tests: tests, mocks: mocks)
  end

  ###
  ### validate_function_names_readable()
  ###

  context "#validate_function_names_readable" do
    def defined(name, signature)
      CExtractorTypes::CFunctionDefinition.new( name: name, signature: signature )
    end

    it "does not raise when every definition has a name" do
      c_module = CExtractorTypes::CModule.new(
        function_definitions:  [defined( 'ticker_get', 'int (*ticker_get(void))(int)' )],
        function_declarations: [CExtractorTypes::CFunctionDeclaration.new( name: 'ticker_count', signature: 'int ticker_count(void);' )]
      )

      expect { @helper.validate_function_names_readable( c_module, 'test_ticker', 'ticker' ) }.not_to raise_error
    end

    it "names the test, the module and the signature of a definition without a name" do
      c_module = CExtractorTypes::CModule.new(
        function_definitions: [defined( 'ticker_count', 'int ticker_count(void)' ), defined( nil, 'int (*ticker_get(void))(int)' )]
      )

      message = <<~MESSAGE.chomp
        Partial test_ticker::ticker ⏩️ Cannot read the name of the function declared by `int (*ticker_get(void))(int)`.

        OPTIONS:
          1. If it returns or takes a function pointer, give that type a name with a typedef and use the name in this declaration.
          2. If a macro generates the declaration, declare the function directly.
      MESSAGE

      expect { @helper.validate_function_names_readable( c_module, 'test_ticker', 'ticker' ) }
        .to raise_error( CeedlingException ) { |error| expect( error.message ).to eq( message ) }
    end

    # A prototype is written word for word and CMock reads its own name, so neither needs one
    it "leaves a declaration without a name alone" do
      c_module = CExtractorTypes::CModule.new(
        function_declarations: [CExtractorTypes::CFunctionDeclaration.new( name: nil, signature: 'int __count__(void);' )]
      )

      expect { @helper.validate_function_names_readable( c_module, 'test_ticker', 'ticker' ) }.not_to raise_error
    end

    it "collapses whitespace in the signature it shows" do
      c_module = CExtractorTypes::CModule.new( function_definitions: [defined( nil, "int  __count__(\n  void )" )] )

      expect { @helper.validate_function_names_readable( c_module, 'test_ticker', 'ticker' ) }
        .to raise_error( CeedlingException, /declared by `int __count__\( void \)`\./ )
    end

    # Extraction reads raw bytes, which may hold any character
    it "shows a signature read as raw bytes" do
      signature = "int caf\xC3\xA9$x(void)".b
      c_module  = CExtractorTypes::CModule.new( function_definitions: [defined( nil, signature )] )

      expect( signature.encoding ).to eq( Encoding::BINARY )
      expect { @helper.validate_function_names_readable( c_module, 'test_ticker', 'ticker' ) }
        .to raise_error( CeedlingException, /declared by `int café\$x\(void\)`\./ )
    end
  end

  ###
  ### validate_function_names_exist()
  ###

  context "#validate_function_names_exist" do
    it "does not raise when all additions and subtractions name existing functions" do
      name     = "test_mod"
      c_module = make_c_module([make_func('foo'), make_func('bar')])
      config   = make_config('mod',
        tests: make_pf(additions: ['foo'], subtractions: ['bar']),
        mocks: make_pf
      )
      expect { @helper.validate_function_names_exist(c_module, config, name) }.not_to raise_error
    end

    it "raises when a tests.additions name is not in function_definitions" do
      name     = "test_mod"
      c_module = make_c_module([make_func('foo')])
      config   = make_config('mod',
        tests: make_pf(additions: ['missing']),
        mocks: make_pf
      )
      expect { @helper.validate_function_names_exist(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*missing/)
    end

    it "raises when a tests.subtractions name is not in function_definitions" do
      name     = "test_mod"
      c_module = make_c_module([make_func('foo')])
      config   = make_config('mod',
        tests: make_pf(subtractions: ['ghost']),
        mocks: make_pf
      )
      expect { @helper.validate_function_names_exist(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*ghost/)
    end

    it "raises when a mocks.additions name is not in function_definitions" do
      name     = "test_mod"
      c_module = make_c_module([make_func('foo')])
      config   = make_config('mod',
        tests: make_pf,
        mocks: make_pf(additions: ['unknown'])
      )
      expect { @helper.validate_function_names_exist(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*unknown/)
    end

    it "raises when a mocks.subtractions name is not in function_definitions" do
      name     = "test_mod"
      c_module = make_c_module([make_func('foo')])
      config   = make_config('mod',
        tests: make_pf,
        mocks: make_pf(subtractions: ['gone'])
      )
      expect { @helper.validate_function_names_exist(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*gone/)
    end

    it "raises a case-mismatch exception when name differs only by case from a known function" do
      name     = "test_mod"
      c_module = make_c_module([make_func('FooBar')])
      config   = make_config('mod',
        tests: make_pf(additions: ['foobar']),
        mocks: make_pf
      )
      expect { @helper.validate_function_names_exist(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*case/)
    end
  end

  ###
  ### validate_no_additions_subtractions_overlap()
  ###

  context "#validate_no_additions_subtractions_overlap" do
    it "does not raise when tests additions and subtractions are disjoint" do
      name   = "test_mod"
      config = make_config('mod',
        tests: make_pf(additions: ['foo'], subtractions: ['bar']),
        mocks: make_pf
      )
      expect { @helper.validate_no_additions_subtractions_overlap(config, name) }.not_to raise_error
    end

    it "does not raise when mocks additions and subtractions are disjoint" do
      name   = "test_mod"
      config = make_config('mod',
        tests: make_pf,
        mocks: make_pf(additions: ['read'], subtractions: ['write'])
      )
      expect { @helper.validate_no_additions_subtractions_overlap(config, name) }.not_to raise_error
    end

    it "raises when a function appears in both tests.additions and tests.subtractions" do
      name   = "test_mod"
      config = make_config('mod',
        tests: make_pf(additions: ['foo'], subtractions: ['foo']),
        mocks: make_pf
      )
      expect { @helper.validate_no_additions_subtractions_overlap(config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*foo/)
    end

    it "raises when a function appears in both mocks.additions and mocks.subtractions" do
      name   = "test_mod"
      config = make_config('mod',
        tests: make_pf,
        mocks: make_pf(additions: ['bar'], subtractions: ['bar'])
      )
      expect { @helper.validate_no_additions_subtractions_overlap(config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*bar/)
    end

    # Only the first overlapping function is reported, since validation aborts the
    # build rather than collecting every problem first.
    it "raises naming the first overlapping function when several overlap" do
      name   = "test_mod"
      config = make_config('mod',
        tests: make_pf(additions: ['alpha', 'beta'], subtractions: ['alpha', 'beta']),
        mocks: make_pf
      )
      expect { @helper.validate_no_additions_subtractions_overlap(config, name) }
        .to raise_error(
          CeedlingException,
          "test_mod: TEST Partial configuration for module 'mod' \u23e9\ufe0f Function 'alpha' should not be both added and subtracted"
        )
    end
  end

  ###
  ### validate_additions_subtractions_visibility()
  ###

  context "#validate_additions_subtractions_visibility" do
    it "does not raise when PUBLIC subtractions are public functions" do
      name     = "test_mod"
      func     = make_func('pub')
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::PUBLIC, subtractions: ['pub']),
        mocks: make_pf
      )
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(func.decorators, Partials::PUBLIC).and_return(true)
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .not_to raise_error
    end

    it "raises when PUBLIC subtractions include a private function" do
      name     = "test_mod"
      func     = make_func('priv', decorators: ['static'])
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::PUBLIC, subtractions: ['priv']),
        mocks: make_pf
      )
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(func.decorators, Partials::PUBLIC).and_return(false)
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*priv/)
    end

    it "does not raise when PRIVATE subtractions are private functions" do
      name     = "test_mod"
      func     = make_func('priv', decorators: ['static'])
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::PRIVATE, subtractions: ['priv']),
        mocks: make_pf
      )
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(func.decorators, Partials::PRIVATE).and_return(true)
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .not_to raise_error
    end

    it "raises when PRIVATE subtractions include a public function" do
      name     = "test_mod"
      func     = make_func('pub')
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::PRIVATE, subtractions: ['pub']),
        mocks: make_pf
      )
      allow(@partializer_utils).to receive(:matches_visibility?)
        .with(func.decorators, Partials::PRIVATE).and_return(false)
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .to raise_error(CeedlingException, /test_mod.*mod.*pub/)
    end

    it "does not raise when PUBLIC additions include a public function (redundant but harmless)" do
      name     = "test_mod"
      func     = make_func('pub')
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::PUBLIC, additions: ['pub']),
        mocks: make_pf
      )
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .not_to raise_error
    end

    it "does not raise when PRIVATE additions include a private function (redundant but harmless)" do
      name     = "test_mod"
      func     = make_func('priv', decorators: ['static'])
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::PRIVATE, additions: ['priv']),
        mocks: make_pf
      )
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .not_to raise_error
    end

    it "skips visibility check for ACCUMULATE type" do
      name     = "test_mod"
      func     = make_func('any')
      c_module = make_c_module([func])
      config   = make_config('mod',
        tests: make_pf(type: Partials::ACCUMULATE, additions: ['any']),
        mocks: make_pf
      )
      expect(@partializer_utils).not_to receive(:matches_visibility?)
      expect { @helper.validate_additions_subtractions_visibility(c_module, config, name) }
        .not_to raise_error
    end
  end

  ###
  ### update_signatures_from_full_expansion()
  ###

  context "#validate_fallback_sufficiency" do
    # Fallback never runs a compiler, so two module shapes are knowably beyond it. Refusing here
    # trades a confusing failure several stages later for a specific one now. Text comes in as a
    # hash so no filesystem is involved.

    def guard(text, name: 'a_test', module_name: 'Foo', filepath: 'src/Foo.h')
      @helper.validate_fallback_sufficiency(
        name: name, module_name: module_name, files: { filepath => text }
      )
    end

    it "accepts a module with no conditionals and ordinary includes" do
      expect {
        guard( "#include \"other.h\"\n#include <stdint.h>\ntypedef int foo_t;\n" )
      }.not_to raise_error
    end

    it "refuses an #include whose target is a macro" do
      expect {
        guard( "#define DEVICE \"dev.h\"\n#include DEVICE\ntypedef int foo_t;\n" )
      }.to raise_error( CeedlingException, /computes an #include target/ )
    end

    it "names the file and the directive's line" do
      expect {
        guard( "typedef int foo_t;\n#define DEVICE \"dev.h\"\n#include DEVICE\n" )
      }.to raise_error( CeedlingException, %r{src/Foo\.h:3} )
    end

    # A directive split across a continuation is attributed to its ending physical line, which
    # is the line the accurate path's own correlation walk would name.
    it "names the ending line of a continued directive" do
      expect {
        guard( "#include \\\n  DEVICE\n" )
      }.to raise_error( CeedlingException, %r{src/Foo\.h:2} )
    end

    it "refuses a type definition behind a condition it cannot evaluate" do
      expect {
        guard( "#if defined(A) && defined(B)\ntypedef long foo_t;\n#else\ntypedef char foo_t;\n#endif\n" )
      }.to raise_error( CeedlingException, /fallback preprocessing cannot evaluate/ )
    end

    it "refuses an include behind a condition it cannot evaluate" do
      expect {
        guard( "#if A > 2\n#include \"wide.h\"\n#endif\n" )
      }.to raise_error( CeedlingException, /fallback preprocessing cannot evaluate/ )
    end

    # Keeping an unevaluable block is the safe default for text the Partial ignores. Only
    # content it relocates makes the guess consequential, so the check is scoped to that.
    # Fallback drops an inactive block along with everything in it, exactly as a real
    # preprocessor would. Refusing over content neither one keeps would fail a build that works.
    it "accepts a computed include inside an inactive block" do
      expect {
        guard( "#if 0\n#include DEVICE\n#endif\ntypedef int foo_t;\n" )
      }.not_to raise_error
    end

    it "accepts an unevaluable condition nested inside an inactive block" do
      expect {
        guard( "#ifdef NEVER_DEFINED\n#if defined(A) && defined(B)\ntypedef long foo_t;\n#endif\n#endif\n" )
      }.not_to raise_error
    end

    it "accepts an unevaluable condition enclosing nothing it relocates" do
      expect {
        guard( "int run(void) {\n#if defined(A) && defined(B)\n  return 1;\n#else\n  return 0;\n#endif\n}\n" )
      }.not_to raise_error
    end

    # These are the shapes the tracker genuinely decides, so a type behind one is not a guess.
    it "accepts a type behind a condition it can evaluate" do
      [
        "#ifdef USE_WIDE\ntypedef long foo_t;\n#else\ntypedef char foo_t;\n#endif\n",
        "#ifndef USE_WIDE\ntypedef char foo_t;\n#endif\n",
        "#if 0\ntypedef long dead_t;\n#endif\ntypedef char foo_t;\n",
        "#if defined(USE_WIDE)\ntypedef long foo_t;\n#endif\n"
      ].each do |text|
        expect { guard( text ) }.not_to raise_error, "unexpectedly refused: #{text.inspect}"
      end
    end

    # Once the unevaluable block closes, later content is decided again and must not inherit the
    # refusal.
    it "accepts a type after an unevaluable block has closed" do
      expect {
        guard( "#if defined(A) && defined(B)\n  int x;\n#endif\ntypedef char foo_t;\n" )
      }.not_to raise_error
    end

    it "checks every file it is handed" do
      expect {
        @helper.validate_fallback_sufficiency(
          name: 'a_test', module_name: 'Foo',
          files: {
            'src/Foo.h' => "typedef int foo_t;\n",
            'src/Foo.c' => "#define DEVICE \"dev.h\"\n#include DEVICE\n"
          }
        )
      }.to raise_error( CeedlingException, %r{src/Foo\.c} )
    end
  end

  context "#update_signatures_from_full_expansion" do
    require 'ceedling/c_extractor/c_extractor_types'

    def make_expanded_func(name:, signature:, decorators:, signature_stripped:, body: nil)
      CExtractorTypes::CFunctionDefinition.new(
        name:               name,
        signature:          signature,
        decorators:         decorators,
        signature_stripped: signature_stripped,
        body:               body
      )
    end

    def make_decl(name:, signature:, decorators:, signature_stripped:)
      CExtractorTypes::CFunctionDeclaration.new(
        name:               name,
        signature:          signature,
        decorators:         decorators,
        signature_stripped: signature_stripped
      )
    end

    it "replaces signature fields from expanded function when name matches" do
      func = double('func',
        name:               'helper',
        signature:          'MY_STATIC int helper(void)',
        decorators:         [],
        signature_stripped: 'int helper(void)'
      )
      allow(func).to receive(:signature=)
      allow(func).to receive(:decorators=)
      allow(func).to receive(:signature_stripped=)
      allow(func).to receive(:expanded_body=)

      expanded_func = make_expanded_func(
        name:               'helper',
        signature:          'static int helper(void)',
        decorators:         ['static'],
        signature_stripped: 'int helper(void)'
      )
      expanded_module = CExtractorTypes::CModule.new(function_definitions: [expanded_func])

      allow(@c_extractor).to receive(:from_file)
        .with('/build/full_expansion/mod.c')
        .and_return(expanded_module)

      expect(func).to receive(:signature=).with('static int helper(void)')
      expect(func).to receive(:decorators=).with(['static'])
      expect(func).to receive(:signature_stripped=).with('int helper(void)')

      @helper.update_signatures_from_full_expansion(
        funcs:                   [func],
        full_expansion_filepath: '/build/full_expansion/mod.c',
        name:                    'TestMod',
        module_name:             'mod',
        file_type:               'source'
      )
    end

    it "leaves function unchanged when name is not found in expanded module" do
      func = double('func',
        name:               'missing',
        signature:          'MACRO int missing(void)',
        decorators:         [],
        signature_stripped: 'int missing(void)'
      )

      expanded_module = CExtractorTypes::CModule.new(function_definitions: [])

      allow(@c_extractor).to receive(:from_file).and_return(expanded_module)

      expect(func).not_to receive(:signature=)
      expect(func).not_to receive(:decorators=)
      expect(func).not_to receive(:signature_stripped=)

      @helper.update_signatures_from_full_expansion(
        funcs:                   [func],
        full_expansion_filepath: '/build/full_expansion/mod.c',
        name:                    'TestMod',
        module_name:             'mod',
        file_type:               'source'
      )
    end

    it "updates only matched functions and skips unmatched ones" do
      func_match = double('matched',
        name:               'private_func',
        signature:          'MY_STATIC void private_func(void)',
        decorators:         [],
        signature_stripped: 'void private_func(void)'
      )
      allow(func_match).to receive(:signature=)
      allow(func_match).to receive(:decorators=)
      allow(func_match).to receive(:signature_stripped=)
      allow(func_match).to receive(:expanded_body=)

      func_no_match = double('unmatched', name: 'orphan')

      expanded_func = make_expanded_func(
        name:               'private_func',
        signature:          'static void private_func(void)',
        decorators:         ['static'],
        signature_stripped: 'void private_func(void)'
      )
      expanded_module = CExtractorTypes::CModule.new(function_definitions: [expanded_func])

      allow(@c_extractor).to receive(:from_file).and_return(expanded_module)

      expect(func_match).to receive(:signature=).with('static void private_func(void)')
      expect(func_match).to receive(:decorators=).with(['static'])
      expect(func_match).to receive(:signature_stripped=).with('void private_func(void)')
      expect(func_no_match).not_to receive(:signature=)
      expect(func_no_match).not_to receive(:decorators=)
      expect(func_no_match).not_to receive(:signature_stripped=)

      @helper.update_signatures_from_full_expansion(
        funcs:                   [func_match, func_no_match],
        full_expansion_filepath: '/build/full_expansion/mod.c',
        name:                    'TestMod',
        module_name:             'mod',
        file_type:               'source'
      )
    end

    it "handles an empty funcs list without error" do
      expanded_module = CExtractorTypes::CModule.new(function_definitions: [])
      allow(@c_extractor).to receive(:from_file).and_return(expanded_module)

      expect {
        @helper.update_signatures_from_full_expansion(
          funcs:                   [],
          full_expansion_filepath: '/build/full_expansion/mod.c',
          name:                    'TestMod',
          module_name:             'mod',
          file_type:               'source'
        )
      }.not_to raise_error
    end

    # The helper scan reads calls a macro hid, so it needs the body as the compiler sees it
    it "keeps each matched definition's expanded body" do
      func = CExtractorTypes::CFunctionDefinition.new(name: 'get', signature: 'int get(int v)', body: '{ return CLAMP(v); }')
      expanded = make_expanded_func(
        name: 'get', signature: 'int get(int v)', decorators: [], signature_stripped: 'int get(int v)',
        body: '{ return clamp(v); }'
      )
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_definitions: [expanded]))

      @helper.update_signatures_from_full_expansion(
        funcs: [func], full_expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(func.expanded_body).to eq('{ return clamp(v); }')
      expect(func.body).to eq('{ return CLAMP(v); }')
    end

    # A carried prototype is written as the user spelled it, so only what the rules read changes
    it "reconciles a declaration's decorators and stripped signature but keeps its written signature" do
      decl = make_decl(name: 'hidden', signature: 'PRIVATE int hidden(void);', decorators: [], signature_stripped: 'PRIVATE int hidden(void);')
      expanded = make_decl(name: 'hidden', signature: 'static int hidden(void);', decorators: ['static'], signature_stripped: 'int hidden(void);')
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: [expanded]))

      @helper.update_signatures_from_full_expansion(
        funcs: [], decls: [decl], full_expansion_filepath: '/build/full_expansion/mod.h',
        name: 'TestMod', module_name: 'mod', file_type: 'header'
      )

      expect(decl.decorators).to eq(['static'])
      expect(decl.signature_stripped).to eq('int hidden(void);')
      expect(decl.signature).to eq('PRIVATE int hidden(void);')
    end

    it "matches declarations that share a name in the order they appear" do
      first  = make_decl(name: 'tick', signature: 'API int tick(void);', decorators: [], signature_stripped: 'API int tick(void);')
      second = make_decl(name: 'tick', signature: 'LOCAL int tick(void);', decorators: [], signature_stripped: 'LOCAL int tick(void);')
      expanded = [
        make_decl(name: 'tick', signature: 'extern int tick(void);', decorators: ['extern'], signature_stripped: 'int tick(void);'),
        make_decl(name: 'tick', signature: 'static int tick(void);', decorators: ['static'], signature_stripped: 'int tick(void);')
      ]
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: expanded))

      @helper.update_signatures_from_full_expansion(
        funcs: [], decls: [first, second], full_expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(first.decorators).to eq(['extern'])
      expect(second.decorators).to eq(['static'])
    end

    it "leaves a declaration unchanged when the expanded copy lacks it" do
      decl = make_decl(name: 'gone', signature: 'int gone(void);', decorators: [], signature_stripped: 'int gone(void);')
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new)

      @helper.update_signatures_from_full_expansion(
        funcs: [], decls: [decl], full_expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(decl.decorators).to eq([])
      expect(decl.signature_stripped).to eq('int gone(void);')
    end

    it "lists a declaration whose decorators changed, marked as a declaration" do
      decl = make_decl(name: 'hidden', signature: 'PRIVATE int hidden(void);', decorators: [], signature_stripped: 'PRIVATE int hidden(void);')
      same = make_decl(name: 'plain', signature: 'int plain(void);', decorators: [], signature_stripped: 'int plain(void);')
      expanded = [
        make_decl(name: 'hidden', signature: 'static int hidden(void);', decorators: ['static'], signature_stripped: 'int hidden(void);'),
        make_decl(name: 'plain', signature: 'int plain(void);', decorators: [], signature_stripped: 'int plain(void);')
      ]
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: expanded))

      expect(@loginator).to receive(:log_list).with(
        ['`hidden` (declaration)'],
        'Updated signatures from full expansion for Partial TestMod::mod header:',
        Verbosity::DEBUG
      )

      @helper.update_signatures_from_full_expansion(
        funcs: [], decls: [decl, same], full_expansion_filepath: '/build/full_expansion/mod.h',
        name: 'TestMod', module_name: 'mod', file_type: 'header'
      )
    end
  end

  context "#mark_inline_elsewhere" do
    require 'ceedling/c_extractor/c_extractor_types'

    def decl(signature)
      CExtractorTypes::CFunctionDeclaration.new(
        name: signature[/(\w+)\s*\(/, 1], signature: signature, decorators: signature.start_with?( 'static' ) ? ['static'] : []
      )
    end

    # Under C99 the declaring file then holds the external definition
    it "marks a declaration whose function an included header defines inline" do
      twice = decl( 'int engine_get_twice(void);' )
      tick  = decl( 'int board_tick(void);' )
      text  = "# 1 \"src/engine_api.h\" 1\nint engine_get(void);\ninline int engine_get_twice(void)\n{\n  return 2;\n}\n" \
              "# 2 \"src/engine.c\" 2\nint engine_get_twice(void);\nint board_tick(void);\n"

      @helper.mark_inline_elsewhere( decls: [twice, tick], text: text )

      expect( twice.inline_elsewhere ).to be(true)
      expect( tick.inline_elsewhere ).to be(false)
    end

    it "marks no declaration of a function a header defines static inline" do
      clamp = decl( 'int clamp(int v);' )

      @helper.mark_inline_elsewhere( decls: [clamp], text: "static inline int clamp(int v) { return v; }\nint clamp(int v);\n" )

      expect( clamp.inline_elsewhere ).to be(false)
    end

    it "marks no static declaration" do
      local = decl( 'static int local(void);' )

      @helper.mark_inline_elsewhere( decls: [local], text: "inline int local(void) { return 1; }\n" )

      expect( local.inline_elsewhere ).to be(false)
    end

    it "marks no declaration of a function a header defines without inline" do
      plain = decl( 'int plain(void);' )

      @helper.mark_inline_elsewhere( decls: [plain], text: "int plain(void) { return 1; }\nint plain(void);\n" )

      expect( plain.inline_elsewhere ).to be(false)
    end

    # A directive line between definitions holds no specifier of the definition after it
    it "reads past a directive line naming static" do
      twice = decl( 'int twice(void);' )

      @helper.mark_inline_elsewhere( decls: [twice], text: "int a;\n#define LOCAL static\ninline int twice(void) { return 2; }\n" )

      expect( twice.inline_elsewhere ).to be(true)
    end

    # A raw copy holds every header the file includes, so the scan has to stay linear in its size.
    # A long stretch with no statement break ahead of the definition is the costly shape.
    it "scans a long stretch with no statement break in linear time" do
      twice = decl( 'int twice(void);' )
      text  = ("#define LIMIT 1\n" * 20_000) + ";\ninline int twice(void) { return 2; }\n"

      Timeout.timeout( 5 ) { @helper.mark_inline_elsewhere( decls: [twice], text: text ) }

      expect( twice.inline_elsewhere ).to be(true)
    end

    it "marks each of several declarations from one call" do
      twice = decl( 'int twice(void);' )
      clamp = decl( 'int clamp(int v);' )
      plain = decl( 'int plain(void);' )
      tick  = decl( 'int tick(void);' )
      text  = "inline int twice(void) { return 2; }\nstatic inline int clamp(int v) { return v; }\n" \
              "int plain(void) { return 1; }\n__inline__ int tick(void)\n{\n  return twice();\n}\n"

      @helper.mark_inline_elsewhere( decls: [twice, clamp, plain, tick], text: text )

      expect( [twice, clamp, plain, tick].map( &:inline_elsewhere ) ).to eq( [true, false, false, true] )
    end

    # A header-only Partial of a large API header asks about every function it declares
    it "marks many declarations in time linear in the text, not in the number of declarations" do
      decls = (1..5_000).map { |n| decl( "int api_#{n}(void);" ) }
      text  = ("#define API_LIMIT 1\n" * 250_000) + ";\ninline int api_77(void) { return 77; }\n"

      Timeout.timeout( 1 ) { @helper.mark_inline_elsewhere( decls: decls, text: text ) }

      expect( decls.select( &:inline_elsewhere ).map( &:name ) ).to eq( ['api_77'] )
    end

    # A block of macros holds no `;` or brace, so the whole block and the definition after it are
    # one stretch of text. Each mention of the name in it is judged by every word ahead of it.
    it "judges many mentions of a name in one stretch of text in linear time" do
      twice = decl( 'int twice(void);' )
      text  = (1..16_000).map { |n| "#define WRAP_#{n}(v) twice(v)\n" }.join + "inline int twice(void) { return 2; }\n"

      Timeout.timeout( 2 ) { @helper.mark_inline_elsewhere( decls: [twice], text: text ) }

      expect( twice.inline_elsewhere ).to be(true)
    end

    # Text read as characters rather than bytes must mark the same
    it "marks from text holding a multibyte character ahead of the definition" do
      twice = decl( 'int twice(void);' )

      @helper.mark_inline_elsewhere( decls: [twice], text: "/* é */ inline int twice(void) { return 2; }\n" )

      expect( twice.inline_elsewhere ).to be(true)
    end

    it "does not take a longer name's inline definition for the declared function's" do
      twice = decl( 'int twice(void);' )

      @helper.mark_inline_elsewhere( decls: [twice], text: "inline int get_twice(void) { return 2; }\n" )

      expect( twice.inline_elsewhere ).to be(false)
    end

    # A raw copy is read as bytes, and a vendor header's comments may hold any byte at all
    it "marks from a raw copy read as bytes, whatever bytes its comments hold" do
      twice = decl( 'int twice(void);' )
      text  = "/* 10 \xB5s tick \xFF */\ninline int twice(void) { return 2; }\n".b

      @helper.mark_inline_elsewhere( decls: [twice], text: text )

      expect( twice.inline_elsewhere ).to be(true)
    end
  end

  context "#associate_declaration_line_numbers" do
    require 'ceedling/c_extractor/c_extractor_types'

    # One call locates every declaration from the file
    it "records each declaration's file and its line in that file's own text" do
      tick = CExtractorTypes::CFunctionDeclaration.new(name: 'tick', signature: 'int tick(void);', line_num: 1)
      tock = CExtractorTypes::CFunctionDeclaration.new(name: 'tock', signature: 'int tock(void);', line_num: 1)
      text = "#include \"x.h\"\nint tick(void);\nint tock(void);\n"
      expect(@partializer_utils).to receive(:locate_declarations_in_text)
        .with(signatures: ['int tick(void);', 'int tock(void);'], text: text).once.and_return([2, 3])

      @helper.associate_declaration_line_numbers(decls: [tick, tock], filepath: 'src/mod.c', text: text)

      expect([tick, tock].map(&:source_filepath)).to eq(['src/mod.c', 'src/mod.c'])
      expect([tick, tock].map(&:line_num)).to eq([2, 3])
    end

    # Without a location the declaration is written without a #line, so nothing is reported
    it "leaves the line unset when the declaration is not found" do
      decl = CExtractorTypes::CFunctionDeclaration.new(name: 'tick', signature: 'int tick(void);', line_num: 1)
      allow(@partializer_utils).to receive(:locate_declarations_in_text).and_return([nil])

      @helper.associate_declaration_line_numbers(decls: [decl], filepath: 'src/mod.c', text: '')

      expect(decl.source_filepath).to eq('src/mod.c')
      expect(decl.line_num).to be_nil
    end
  end

end
