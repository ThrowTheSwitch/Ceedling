# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'
require 'ceedling/preprocess/preprocessinator_file_assembler'
require 'ceedling/preprocess/preprocessinator_reconstructor'
require 'ceedling/parsing_parcels'
require 'ceedling/encodinator'

RSpec.describe PreprocessinatorFileAssembler do

  # Use real ParsingParcels for _filter_conditionals and collect_file_contents_fallback tests
  let(:real_parsing_parcels) { ParsingParcels.new }
  let(:real_reconstructor) do
    PreprocessinatorReconstructor.new({ parsing_parcels: real_parsing_parcels })
  end

  before :each do
    @configurator   = double('configurator')
    @tool_executor  = double('tool_executor')
    @file_path_utils = double('file_path_utils')
    @file_wrapper   = double('file_wrapper')
    @loginator      = double('loginator')
    @reportinator   = double('reportinator')

    allow(@loginator).to receive(:log)
    allow(@reportinator).to receive(:generate_module_progress).and_return('')
  end

  subject do
    PreprocessinatorFileAssembler.new(
      {
        preprocessinator_reconstructor: real_reconstructor,
        configurator:    @configurator,
        tool_executor:   @tool_executor,
        file_path_utils: @file_path_utils,
        file_wrapper:    @file_wrapper,
        parsing_parcels: real_parsing_parcels,
        loginator:       @loginator,
        reportinator:    @reportinator
      }
    )
  end

  # Helper: stub file_wrapper.open to yield StringIO of content
  def stub_file_open(filepath, content, mode='rb')
    allow(@file_wrapper).to receive(:open).with(filepath, mode).and_yield(StringIO.new(content))
  end


  # ===========================================================================
  describe '#collect_file_contents_fallback' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }


    context 'preprocessor directive stripping' do

      it 'strips #include directives from output' do
        stub_file_open(filepath, "#include \"foo.h\"\nint x = 0;\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).not_to include('#include "foo.h"')
        expect(result).to include('int x = 0;')
      end

      it 'strips #define directives from output' do
        stub_file_open(filepath, "#define MAX 100\nint x = 0;\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).not_to include('#define MAX 100')
        expect(result).to include('int x = 0;')
      end

      it 'strips #pragma directives from output' do
        stub_file_open(filepath, "#pragma once\nint x = 0;\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).not_to include('#pragma once')
        expect(result).to include('int x = 0;')
      end

      it 'strips #ifdef and #endif directives from output' do
        content = "#ifdef FOO\nint x = 0;\n#endif\n"
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(source_filepath: filepath, defines: ['FOO'])
        expect(result.join).not_to match(/#\s*ifdef/)
        expect(result.join).not_to match(/#\s*endif/)
      end

      it 'strips #undef directives from output' do
        stub_file_open(filepath, "#undef MAX\nint x = 0;\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).not_to include('#undef MAX')
        expect(result).to include('int x = 0;')
      end

      it 'strips directives with leading whitespace' do
        stub_file_open(filepath, "  #include <stdio.h>\nint x = 0;\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result.join(' ')).not_to match(/#include/)
        expect(result).to include('int x = 0;')
      end

      it 'returns an empty array for a file containing only preprocessor directives' do
        content = "#include \"foo.h\"\n#define BAR 1\n#pragma once\n"
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result.reject { |l| l.strip.empty? }).to be_empty
      end

    end


    context 'code line preservation' do

      it 'preserves function declarations' do
        stub_file_open(filepath, "void my_func(int x);\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).to include('void my_func(int x);')
      end

      it 'preserves function bodies' do
        content = "void my_func(void) {\n  return;\n}\n"
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).to include('void my_func(void) {')
        expect(result).to include('  return;')
        expect(result).to include('}')
      end

      it 'preserves inline // comments on code lines' do
        stub_file_open(filepath, "int x = 0;  // initialize counter\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).to include('int x = 0;  // initialize counter')
      end

      it 'preserves block comments on code lines' do
        stub_file_open(filepath, "int x = 0; /* zero-init */\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).to include('int x = 0; /* zero-init */')
      end

      it 'preserves standalone comment lines' do
        stub_file_open(filepath, "/* Full-line comment. */\nint x = 0;\n")
        result = subject.collect_file_contents_fallback(source_filepath: filepath)
        expect(result).to include('/* Full-line comment. */')
      end

    end


    context 'conditional filtering with defines' do

      it 'excludes code inside inactive #ifdef block' do
        content = <<~C
          int a = 1;
          #ifdef UNDEFINED_MACRO
          int b = 2;
          #endif
          int c = 3;
        C
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(source_filepath: filepath, defines: [])
        lines = result.map(&:strip).reject(&:empty?)
        expect(lines).to include('int a = 1;')
        expect(lines).not_to include('int b = 2;')
        expect(lines).to include('int c = 3;')
      end

      it 'includes code inside active #ifdef block' do
        content = <<~C
          int a = 1;
          #ifdef MY_FEATURE
          int b = 2;
          #endif
          int c = 3;
        C
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(
          source_filepath: filepath, defines: ['MY_FEATURE']
        )
        lines = result.map(&:strip).reject(&:empty?)
        expect(lines).to include('int a = 1;')
        expect(lines).to include('int b = 2;')
        expect(lines).to include('int c = 3;')
      end

      it 'includes #else branch when #ifdef is inactive' do
        content = <<~C
          #ifdef PLATFORM_A
          int platform = 0;
          #else
          int platform = 1;
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(source_filepath: filepath, defines: [])
        lines = result.map(&:strip).reject(&:empty?)
        expect(lines).not_to include('int platform = 0;')
        expect(lines).to include('int platform = 1;')
      end

      it 'excludes #else branch when #ifdef is active' do
        content = <<~C
          #ifdef PLATFORM_A
          int platform = 0;
          #else
          int platform = 1;
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.collect_file_contents_fallback(
          source_filepath: filepath, defines: ['PLATFORM_A']
        )
        lines = result.map(&:strip).reject(&:empty?)
        expect(lines).to include('int platform = 0;')
        expect(lines).not_to include('int platform = 1;')
      end

    end


    context 'encoding safety' do

      it 'does not raise on UTF-8 characters in comments; keeps comment lines in output' do
        # clean_encoding strips non-ASCII (© etc.) but must not crash.
        # The comment line itself should still appear in output.
        stub_file_open(filepath, "/* © 2024 — résumé */\nint x = 0;\n")
        result = nil
        expect { result = subject.collect_file_contents_fallback(source_filepath: filepath) }.not_to raise_error
        expect(result).not_to be_empty
        expect(result).to include('int x = 0;')
      end

      it 'does not raise on non-ASCII in kept code lines' do
        stub_file_open(filepath, "int x = 0;  // naïve\n")
        expect {
          result = subject.collect_file_contents_fallback(source_filepath: filepath)
          expect(result).not_to be_empty
        }.not_to raise_error
      end

      it 'does not raise on non-ASCII near conditional directives' do
        content = "/* © */\n#ifdef FEATURE\nint x = 1;\n#endif\n"
        stub_file_open(filepath, content)
        expect {
          result = subject.collect_file_contents_fallback(
            source_filepath: filepath, defines: ['FEATURE']
          )
          lines = result.map(&:strip).reject(&:empty?)
          expect(lines).to include('int x = 1;')
        }.not_to raise_error
      end

    end

  end


  # ===========================================================================
  describe '#collect_mockable_header_file_contents' do
  # ===========================================================================

    let(:test) { 'test_module' }
    let(:filepath) { '/src/module.h' }
    let(:directives_only_filepath) { '/build/directives/module.h' }
    let(:preprocessed_filepath) { '/build/full_expansion/module.h' }
    let(:flags) { [] }
    let(:defines) { [] }
    let(:include_paths) { [] }

    before :each do
      allow(@file_path_utils).to receive(:form_preprocessed_file_full_expansion_filepath)
        .with(filepath, test).and_return(preprocessed_filepath)
      allow(@configurator).to receive(:tools_test_file_full_preprocessor).and_return(:full_preprocessor)
      allow(@tool_executor).to receive(:build_command_line).and_return('gcc -E ...')
      allow(@tool_executor).to receive(:exec)
      stub_file_open(preprocessed_filepath, "# 1 \"#{filepath}\"\nint x;\n", 'r')
    end

    def call_collect_mockable(fallback:, extras:)
      subject.collect_mockable_header_file_contents(
        test: test,
        filepath: filepath,
        directives_only_filepath: directives_only_filepath,
        fallback: fallback,
        flags: flags,
        defines: defines,
        include_paths: include_paths,
        extras: extras
      )
    end

    context 'when extras are not requested' do

      it 'returns an empty extras list and a nil include guard' do
        _contents, extras, include_guard = call_collect_mockable(fallback: true, extras: false)
        expect(extras).to eq([])
        expect(include_guard).to be_nil
      end

      it 'does not read the original file to look for an include guard' do
        expect(@file_wrapper).not_to receive(:read)
        call_collect_mockable(fallback: true, extras: false)
      end

    end

    context 'when extras are requested' do

      let(:header_with_guard) do
        <<~C
          #ifndef FOO_H
          #define FOO_H

          void foo(void);

          #endif
        C
      end

      it 'extracts the include guard from the original file in fallback mode' do
        allow(@file_wrapper).to receive(:read).with(filepath, 2048).and_return(header_with_guard)
        stub_file_open(filepath, header_with_guard, 'rb')

        _contents, _extras, include_guard = call_collect_mockable(fallback: true, extras: true)
        expect(include_guard).to eq('FOO_H')
      end

      it 'extracts the include guard from the original file in directives-only mode' do
        allow(@file_wrapper).to receive(:read).with(filepath, 2048).and_return(header_with_guard)
        stub_file_open(directives_only_filepath, header_with_guard, 'r')

        _contents, _extras, include_guard = call_collect_mockable(fallback: false, extras: true)
        expect(include_guard).to eq('FOO_H')
      end

      it 'returns a nil include guard when the original file has no #ifndef/#define guard pair' do
        header_without_guard = "#pragma once\n\nvoid foo(void);\n"
        allow(@file_wrapper).to receive(:read).with(filepath, 2048).and_return(header_without_guard)
        stub_file_open(filepath, header_without_guard, 'rb')

        _contents, _extras, include_guard = call_collect_mockable(fallback: true, extras: true)
        expect(include_guard).to be_nil
      end

    end

  end


  # ===========================================================================
  describe '#assemble_preprocessed_header_file' do
  # ===========================================================================

    let(:preprocessed_filepath) { '/build/mocks/test_module/module.h' }

    def stub_file_write(filepath)
      output = StringIO.new
      allow(@file_wrapper).to receive(:open).with(filepath, 'w').and_yield(output)
      output
    end

    it 'writes the given include guard name as the #ifndef/#define/#endif guard' do
      output = stub_file_write(preprocessed_filepath)

      subject.assemble_preprocessed_header_file(
        filename:              'module.h',
        preprocessed_filepath: preprocessed_filepath,
        contents:              ['void foo(void);'],
        extras:                [],
        includes:              [],
        include_guard:         'FOO_H'
      )

      expect(output.string).to include("#ifndef FOO_H\n")
      expect(output.string).to include("#define FOO_H\n")
      expect(output.string).to include('#endif // FOO_H')
    end

    it 'derives a synthetic include guard from the filename when none is given' do
      output = stub_file_write(preprocessed_filepath)

      subject.assemble_preprocessed_header_file(
        filename:              'module.h',
        preprocessed_filepath: preprocessed_filepath,
        contents:              ['void foo(void);'],
        extras:                [],
        includes:              []
      )

      expect(output.string).to include("#ifndef __CEEDLING_GENERATED_MODULE_H__\n")
      expect(output.string).to include("#define __CEEDLING_GENERATED_MODULE_H__\n")
    end

    it 'writes provided includes and contents between the guard lines' do
      output = stub_file_write(preprocessed_filepath)

      subject.assemble_preprocessed_header_file(
        filename:              'module.h',
        preprocessed_filepath: preprocessed_filepath,
        contents:              ['void foo(void);'],
        extras:                [],
        includes:              ['#include "bar.h"'],
        include_guard:         'FOO_H'
      )

      expect(output.string).to include('#include "bar.h"')
      expect(output.string).to include('void foo(void);')
    end

  end

end
