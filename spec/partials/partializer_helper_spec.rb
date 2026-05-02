
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'spec_helper'
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partializer_utils'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_declarations'
require 'ostruct'

describe PartializerHelper do
  before(:each) do
    @partializer_utils        = double("PartializerUtils")
    @c_extractor_declarations = double("CExtractorDeclarations")
    @file_path_utils          = double("FilePathUtils")
    @loginator                = double("Loginator").as_null_object

    @helper = described_class.new(
      {
        :partializer_utils        => @partializer_utils,
        :c_extractor_declarations => @c_extractor_declarations,
        :file_path_utils          => @file_path_utils,
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
    end

    it "calls stamp_source_filepaths for empty funcs with fallback: false" do
      expect(@partializer_utils).to receive(:stamp_source_filepaths).with([], @filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "calls stamp_source_filepaths for empty funcs with fallback: true" do
      expect(@partializer_utils).to receive(:stamp_source_filepaths).with([], @filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: true)
    end

    it "makes no locate calls when funcs is empty" do
      expect(@partializer_utils).not_to receive(:locate_function_in_source)
      expect(@partializer_utils).not_to receive(:locate_function_via_preprocessed)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "constructs preprocessed filepath from name and filepath" do
      expect(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(@preprocessed_filepath)

      @helper.associate_function_line_numbers(name: @name, funcs: [], filepath: @filepath, fallback: false)
    end

    it "uses locate_function_in_source for each func when fallback: true" do
      func1 = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)
      func2 = OpenStruct.new(code_block: 'int bar(int x) {}', line_num: nil)

      expect(@partializer_utils).to receive(:locate_function_in_source)
        .with(code_block: func1.code_block, filepath: @filepath)
        .and_return(10)
      expect(@partializer_utils).to receive(:locate_function_in_source)
        .with(code_block: func2.code_block, filepath: @filepath)
        .and_return(25)

      @helper.associate_function_line_numbers(name: @name, funcs: [func1, func2], filepath: @filepath, fallback: true)

      expect(func1.line_num).to eq(10)
      expect(func2.line_num).to eq(25)
    end

    it "uses locate_function_via_preprocessed for each func when fallback: false" do
      func1 = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)
      func2 = OpenStruct.new(code_block: 'int bar(int x) {}', line_num: nil)

      expect(@partializer_utils).to receive(:locate_function_via_preprocessed)
        .with(code_block: func1.code_block, filepath: @filepath, preprocessed_filepath: @preprocessed_filepath)
        .and_return(10)
      expect(@partializer_utils).to receive(:locate_function_via_preprocessed)
        .with(code_block: func2.code_block, filepath: @filepath, preprocessed_filepath: @preprocessed_filepath)
        .and_return(25)

      @helper.associate_function_line_numbers(name: @name, funcs: [func1, func2], filepath: @filepath, fallback: false)

      expect(func1.line_num).to eq(10)
      expect(func2.line_num).to eq(25)
    end

    it "sets line_num to nil when locate_function_via_preprocessed returns nil" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      allow(@partializer_utils).to receive(:locate_function_via_preprocessed).and_return(nil)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)

      expect(func.line_num).to be_nil
    end

    it "does not call locate_function_via_preprocessed when fallback: true" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      expect(@partializer_utils).not_to receive(:locate_function_via_preprocessed)
      allow(@partializer_utils).to receive(:locate_function_in_source).and_return(1)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: true)
    end

    it "does not call locate_function_in_source when fallback: false" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      expect(@partializer_utils).not_to receive(:locate_function_in_source)
      allow(@partializer_utils).to receive(:locate_function_via_preprocessed).and_return(1)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end

    it "calls format_line_number_list with funcs and passes result to loginator" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil, name: 'foo')

      allow(@partializer_utils).to receive(:locate_function_via_preprocessed).and_return(5)

      expect(@partializer_utils).to receive(:format_line_number_list).with([func]).and_return(["foo(): 5"])

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
    end

    it "forwards the constructed preprocessed_filepath to locate_function_via_preprocessed" do
      func = OpenStruct.new(code_block: 'void foo(void) {}', line_num: nil)

      custom_preproc = '/custom/preproc/output.i'
      allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath)
        .with(@filepath, @name)
        .and_return(custom_preproc)

      expect(@partializer_utils).to receive(:locate_function_via_preprocessed)
        .with(hash_including(preprocessed_filepath: custom_preproc))
        .and_return(nil)

      @helper.associate_function_line_numbers(name: @name, funcs: [func], filepath: @filepath, fallback: false)
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

        expect(@partializer_utils).not_to receive(:replace_declaration_with_noop)
        expect(@partializer_utils).not_to receive(:rename_c_identifier)

        result = @helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')
        expect(result).to eq([])
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

        expect(@partializer_utils).not_to receive(:replace_declaration_with_noop)
        expect(@partializer_utils).not_to receive(:rename_c_identifier)

        result = @helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')
        expect(result).to eq([])
      end

      it "delegates noop and rename calls to utils for a static variable" do
        func = OpenStruct.new(
          name: 'process',
          code_block: 'void process(void) { static int count; count = 0; }',
          body: '{ static int count; count = 0; }'
        )

        var = OpenStruct.new(
          original:    'static int count',
          name:        'count',
          decorators:  ['static'],
          text: 'int count;'
        )

        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([true, [var]], [false, nil])

        placeholder = '__CEEDLING_NOOP_PROCESS_COUNT__'
        noop_text   = "(void)0; /* `#{placeholder}` ... */"

        allow(@partializer_utils).to receive(:replace_declaration_with_noop)
          .and_return(noop_text)
        allow(@partializer_utils).to receive(:rename_c_identifier)
          .and_return('')

        result = @helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(@partializer_utils).to have_received(:replace_declaration_with_noop).exactly(2).times
        expect(@partializer_utils).to have_received(:rename_c_identifier).exactly(3).times
        expect(result.first.name).to eq('partial_process_count')
      end

      it "delegates compound noop and rename calls to utils for a compound static declaration" do
        func = OpenStruct.new(
          name: 'calc',
          code_block: 'void calc(void) { static int a, b; a = 0; b = 1; }',
          body: '{ static int a, b; a = 0; b = 1; }'
        )

        shared_original = 'static int a, b;'
        var_a = OpenStruct.new(
          original:    shared_original,
          name:        'a',
          decorators:  ['static'],
          text: 'int a;'
        )
        var_b = OpenStruct.new(
          original:    shared_original,
          name:        'b',
          decorators:  ['static'],
          text: 'int b;'
        )

        # Scanner returns both vars in one call, then fails
        allow(@c_extractor_declarations).to receive(:try_extract_variable)
          .and_return([true, [var_a, var_b]], [false, nil])

        placeholder = '__CEEDLING_NOOP_CALC_A__'
        noops       = "(void)0; (void)0; /* `#{placeholder}` ... */"

        allow(@partializer_utils).to receive(:replace_compound_declaration_with_noops)
          .and_return(noops)
        allow(@partializer_utils).to receive(:rename_c_identifier)
          .and_return('')

        result = @helper.extract_function_scope_static_vars([func], name: 'test', module_name: 'mod', file_type: 'source')

        expect(@partializer_utils).to have_received(:replace_compound_declaration_with_noops)
          .with(anything, shared_original, placeholder, 2)
          .exactly(2).times
        expect(@partializer_utils).to have_received(:rename_c_identifier).exactly(6).times
        expect(result.map(&:name)).to contain_exactly('partial_calc_a', 'partial_calc_b')
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
            :c_extractor_declarations => CExtractorDeclarations.new,
            :file_path_utils          => double("FilePathUtils"),
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

end
