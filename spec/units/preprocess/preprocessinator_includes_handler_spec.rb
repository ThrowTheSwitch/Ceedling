# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'
require 'ceedling/preprocess/preprocessinator_includes_handler'
require 'ceedling/preprocess/preprocessinator_line_marker_includes_extractor'
require 'ceedling/parsing_parcels'
require 'ceedling/includes/includes'
require 'ceedling/encodinator'

RSpec.describe PreprocessinatorIncludesHandler do

  # Use real ParsingParcels so code_lines / conditional tracking works correctly
  let(:real_parsing_parcels) { ParsingParcels.new }

  before :each do
    @configurator    = double('configurator')
    @include_factory = double('include_factory')
    @file_wrapper    = double('file_wrapper')
    @yaml_wrapper    = double('yaml_wrapper')
    @loginator       = double('loginator')
    @reportinator    = double('reportinator')
    @preprocessinator_line_marker_includes_extractor =
      double('preprocessinator_line_marker_includes_extractor')

    allow(@loginator).to receive(:log)
    allow(@reportinator).to receive(:generate_module_progress).and_return('')

    # Include factory helpers: return typed Include objects based on the path
    allow(@include_factory).to receive(:user_include_from_directive) do |line|
      m = line.match(PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME)
      m ? UserInclude.new(m[1]) : nil
    end

    allow(@include_factory).to receive(:system_include_from_directive) do |line|
      m = line.match(PATTERNS::SYSTEM_INCLUDE_DIRECTIVE_FILENAME)
      m ? SystemInclude.new(m[1]) : nil
    end
  end

  subject do
    PreprocessinatorIncludesHandler.new(
      {
        configurator:           @configurator,
        include_factory:        @include_factory,
        preprocessinator_line_marker_includes_extractor:
          @preprocessinator_line_marker_includes_extractor,
        tool_executor:          double('tool_executor'),
        file_wrapper:           @file_wrapper,
        yaml_wrapper:           @yaml_wrapper,
        parsing_parcels:        real_parsing_parcels,
        loginator:              @loginator,
        reportinator:           @reportinator
      }
    )
  end

  # Helper: yield StringIO of content from file_wrapper.open
  def stub_file_open(filepath, content)
    allow(@file_wrapper).to receive(:open).with(filepath, 'rb').and_yield(StringIO.new(content))
  end


  # ===========================================================================
  describe '#extract_user_includes_from_text' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    context 'basic extraction' do

      it 'extracts a simple user include' do
        stub_file_open(filepath, "#include \"foo.h\"\n")
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath)
        expect(result.map(&:filename)).to include('foo.h')
      end

      it 'extracts multiple user includes' do
        content = "#include \"alpha.h\"\n#include \"beta.h\"\n"
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath)
        expect(result.map(&:filename)).to contain_exactly('alpha.h', 'beta.h')
      end

      it 'does not extract system includes' do
        stub_file_open(filepath, "#include <stdio.h>\n")
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath)
        expect(result).to be_empty
      end

      it 'ignores includes inside line comments' do
        stub_file_open(filepath, "// #include \"commented_out.h\"\n")
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath)
        expect(result).to be_empty
      end

      it 'ignores includes inside block comments' do
        content = "/* #include \"in_block.h\" */\n#include \"real.h\"\n"
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath)
        expect(result.map(&:filename)).to contain_exactly('real.h')
      end

    end


    context 'with defines: [] (no macros defined)' do

      it 'skips include inside #ifdef block when no defines provided' do
        content = <<~C
          #include "always.h"
          #ifdef FEATURE_A
          #include "conditional.h"
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath, defines: [])
        expect(result.map(&:filename)).to contain_exactly('always.h')
      end

      it 'includes the #else branch when #ifdef undefined' do
        content = <<~C
          #ifdef UNDEFINED
          #include "a.h"
          #else
          #include "b.h"
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath, defines: [])
        expect(result.map(&:filename)).to contain_exactly('b.h')
      end

    end


    context 'with active defines' do

      it 'includes the #ifdef branch when macro is defined' do
        content = <<~C
          #ifdef FEATURE_A
          #include "feature_a.h"
          #else
          #include "feature_b.h"
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(
          name: 'test', filepath: filepath, defines: ['FEATURE_A']
        )
        expect(result.map(&:filename)).to contain_exactly('feature_a.h')
      end

      it 'skips the #else branch when #ifdef macro is defined' do
        content = <<~C
          #ifdef FEATURE_A
          #include "yes.h"
          #else
          #include "no.h"
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(
          name: 'test', filepath: filepath, defines: ['FEATURE_A']
        )
        expect(result.map(&:filename)).to contain_exactly('yes.h')
        expect(result.map(&:filename)).not_to include('no.h')
      end

      it 'handles nested #ifdef correctly' do
        content = <<~C
          #ifdef OUTER
          #include "outer.h"
          #ifdef INNER
          #include "inner.h"
          #endif
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(
          name: 'test', filepath: filepath, defines: ['OUTER']
        )
        # INNER not defined, so inner.h should be excluded
        expect(result.map(&:filename)).to contain_exactly('outer.h')
      end

      it 'handles -D prefix in defines list' do
        content = <<~C
          #ifdef FEATURE
          #include "feature.h"
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(
          name: 'test', filepath: filepath, defines: ['-DFEATURE']
        )
        expect(result.map(&:filename)).to contain_exactly('feature.h')
      end

      it 'handles defines with =value suffix' do
        content = <<~C
          #ifdef VERSION
          #include "version.h"
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_user_includes_from_text(
          name: 'test', filepath: filepath, defines: ['VERSION=3']
        )
        expect(result.map(&:filename)).to contain_exactly('version.h')
      end

    end


    context 'encoding safety' do

      it 'does not raise on non-ASCII UTF-8 characters in comments adjacent to includes' do
        content = "/* © 2024 Résumé Corp. */\n#include \"safe.h\"\n"
        stub_file_open(filepath, content)
        expect {
          result = subject.extract_user_includes_from_text(name: 'test', filepath: filepath)
          expect(result.map(&:filename)).to contain_exactly('safe.h')
        }.not_to raise_error
      end

      it 'does not raise on non-ASCII near a conditional directive' do
        content = <<~C
          /* Ünïcödé header © 2024 */
          #ifdef FEATURE  /* naïve check */
          #include "feature.h"
          #endif
        C
        stub_file_open(filepath, content)
        expect {
          result = subject.extract_user_includes_from_text(
            name: 'test', filepath: filepath, defines: ['FEATURE']
          )
          expect(result.map(&:filename)).to contain_exactly('feature.h')
        }.not_to raise_error
      end

    end

  end


  # ===========================================================================
  describe '#extract_system_includes_from_text' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    context 'basic extraction' do

      it 'extracts a simple system include' do
        stub_file_open(filepath, "#include <stdio.h>\n")
        result = subject.extract_system_includes_from_text(name: 'test', filepath: filepath)
        expect(result.map(&:filename)).to include('stdio.h')
      end

      it 'does not extract user includes' do
        stub_file_open(filepath, "#include \"user.h\"\n")
        result = subject.extract_system_includes_from_text(name: 'test', filepath: filepath)
        expect(result).to be_empty
      end

    end


    context 'with conditional filtering' do

      it 'skips system include in inactive #ifdef block' do
        content = <<~C
          #include <always.h>
          #ifdef PLATFORM_A
          #include <platform_a.h>
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_system_includes_from_text(
          name: 'test', filepath: filepath, defines: []
        )
        expect(result.map(&:filename)).to contain_exactly('always.h')
      end

      it 'includes system include in active #ifdef block' do
        content = <<~C
          #ifdef USE_STDLIB
          #include <stdlib.h>
          #endif
        C
        stub_file_open(filepath, content)
        result = subject.extract_system_includes_from_text(
          name: 'test', filepath: filepath, defines: ['USE_STDLIB']
        )
        expect(result.map(&:filename)).to contain_exactly('stdlib.h')
      end

      it 'handles #ifndef correctly for system includes' do
        content = <<~C
          #ifndef NO_STDLIB
          #include <stdlib.h>
          #endif
        C
        stub_file_open(filepath, content)
        # NO_STDLIB is NOT defined, so #ifndef is active → should include
        result = subject.extract_system_includes_from_text(
          name: 'test', filepath: filepath, defines: []
        )
        expect(result.map(&:filename)).to contain_exactly('stdlib.h')
      end

    end


    context 'encoding safety' do

      it 'does not raise on non-ASCII UTF-8 characters near system includes' do
        content = "/* Résumé header © */\n#include <system.h>\n"
        stub_file_open(filepath, content)
        expect {
          result = subject.extract_system_includes_from_text(name: 'test', filepath: filepath)
          expect(result.map(&:filename)).to contain_exactly('system.h')
        }.not_to raise_error
      end

    end

  end

end
