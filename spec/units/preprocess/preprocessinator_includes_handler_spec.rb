# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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
    @configurator     = double('configurator')
    @include_factory  = double('include_factory')
    @file_wrapper     = double('file_wrapper')
    @file_path_utils  = double('file_path_utils')
    @tool_executor    = double('tool_executor')
    @yaml_wrapper     = double('yaml_wrapper')
    @loginator        = double('loginator')
    @reportinator     = double('reportinator')
    @preprocessinator_line_marker_includes_extractor =
      double('preprocessinator_line_marker_includes_extractor')

    allow(@loginator).to receive(:log)
    allow(@loginator).to receive(:lazy)
    allow(@loginator).to receive(:log_list)
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
        tool_executor:          @tool_executor,
        file_wrapper:           @file_wrapper,
        file_path_utils:        @file_path_utils,
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
  describe '#extract_bare_includes' do
  # ===========================================================================
  # Extraction stages an isolated, sibling-free copy of the file being scanned before running
  # GCC's bare-includes preprocessor pass, so that GCC's own directory-relative #include
  # resolution has no real sibling header available to find and recurse into.

    let(:test_name)         { 'test_other' }
    let(:filepath)          { '/project/test/test_other.c' }
    let(:isolation_parent)  { '/project/build/test/preprocess/files/test_other' }
    let(:isolation_dir)     { "#{isolation_parent}/tmp1234" }
    let(:isolated_filepath) { "#{isolation_dir}/test_other.c" }
    let(:make_rules) do
      "test_other.o: #{isolated_filepath} unity.h mock_foo_func.h other.h\n\n" \
      "unity.h:\n\nmock_foo_func.h:\n\nother.h:\n"
    end

    before :each do
      allow(@file_path_utils).to receive(:form_test_preprocess_files_path)
        .with(test_name).and_return(isolation_parent)
      allow(@file_wrapper).to receive(:stage_isolated_copies)
        .with(parent: isolation_parent, files: [filepath]).and_return(isolation_dir)
      allow(@file_wrapper).to receive(:remove_isolated_copies).with(isolation_dir)

      allow(@configurator).to receive(:tools_test_bare_includes_preprocessor).and_return(:bare_tool)

      allow(@tool_executor).to receive(:build_command_line) do |tool, extra_args, fp, defs, flgs, paths|
        { options: {}, tool: tool, filepath: fp, defines: defs, flags: flgs, search_paths: paths }
      end

      allow(@tool_executor).to receive(:exec).and_return(output: make_rules)
    end

    def call_it
      subject.extract_bare_includes(
        test: test_name, filepath: filepath, search_paths: [], flags: [], defines: []
      )
    end

    it 'stages a copy of the file into an isolated, sibling-free directory before extraction' do
      call_it()

      expect(@file_wrapper).to have_received(:stage_isolated_copies).with(parent: isolation_parent, files: [filepath])
    end

    it 'builds the bare-includes command against the isolated staged path, not the original' do
      call_it()

      expect(@tool_executor).to have_received(:build_command_line)
        .with(:bare_tool, [], isolated_filepath, [], [], [])
    end

    it 'returns the includes parsed from the staged file make-rule output' do
      result = call_it()
      expect(result.map(&:filename)).to contain_exactly('unity.h', 'mock_foo_func.h', 'other.h')
    end

    it 'cleans up the isolation directory after a successful run' do
      call_it()
      expect(@file_wrapper).to have_received(:remove_isolated_copies).with(isolation_dir)
    end

    it 'cleans up the isolation directory even when the tool executor raises' do
      allow(@tool_executor).to receive(:exec).and_raise(StandardError.new('boom'))

      expect { call_it() }.to raise_error(StandardError, 'boom')

      expect(@file_wrapper).to have_received(:remove_isolated_copies).with(isolation_dir)
    end

    it 'still cleans self-reference against the original filepath identity, not the staged copy' do
      self_ref_rules =
        "test_other.o: #{isolated_filepath} #{filepath} other.h\n\n#{filepath}:\n\nother.h:\n"
      allow(@tool_executor).to receive(:exec).and_return(output: self_ref_rules)

      result = call_it()
      expect(result.map(&:filename)).to contain_exactly('other.h')
    end

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
  describe '#extract_bare_includes_from_text' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    it 'extracts a simple user include' do
      stub_file_open(filepath, "#include \"foo.h\"\n")
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result.map(&:filename)).to include('foo.h')
    end

    it 'extracts a system include too, unlike extract_user_includes_from_text' do
      stub_file_open(filepath, "#include <stdio.h>\n")
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result.map(&:filename)).to include('stdio.h')
    end

    it 'returns plain Include objects, not UserInclude/SystemInclude' do
      stub_file_open(filepath, "#include \"foo.h\"\n#include <stdio.h>\n")
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result).to all( be_an_instance_of(Include) )
    end

    it 'ignores includes inside line comments' do
      stub_file_open(filepath, "// #include \"commented_out.h\"\n")
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result).to be_empty
    end

    it 'ignores includes inside block comments' do
      content = "/* #include \"in_block.h\" */\n#include \"real.h\"\n"
      stub_file_open(filepath, content)
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result.map(&:filename)).to contain_exactly('real.h')
    end

    # The defining difference from extract_user_includes_from_text: no conditional
    # tracking at all -- an #include inside an #ifdef for an undefined macro is
    # still captured, since this method's whole purpose is to see past a guard
    # whose condition can't be evaluated without opening another header (issue #1223).
    it 'captures a conditionally-guarded include regardless of whether the guard could be evaluated true' do
      content = <<~C
        #ifdef UNDEFINED_MACRO
        #include "conditional.h"
        #endif
      C
      stub_file_open(filepath, content)
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result.map(&:filename)).to include('conditional.h')
    end

    it 'removes a self-referential include matching the file being scanned' do
      stub_file_open(filepath, "#include \"#{filepath}\"\n#include \"foo.h\"\n")
      result = subject.extract_bare_includes_from_text(filepath: filepath)
      expect(result.map(&:filename)).to contain_exactly('foo.h')
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


  # ===========================================================================
  describe '#extract_user_includes_preprocess' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    it 'delegates to the line-marker extractor with USER type, no depth limit, and the test name' do
      expect(@preprocessinator_line_marker_includes_extractor).to receive(:extract_includes_from_file).with(
        '/build/directives_only/module.c',
        PreprocessinatorLineMarkerIncludesExtractor::USER,
        test: 'test'
      ).and_return( [ UserInclude.new('widget.h') ] )

      result = subject.extract_user_includes_preprocess(
        name: 'test', filepath: filepath, preprocessed_filepath: '/build/directives_only/module.c'
      )

      expect(result.map(&:filename)).to eq(['widget.h'])
    end

    it 'removes a self-referential entry matching the file being processed' do
      allow(@preprocessinator_line_marker_includes_extractor).to receive(:extract_includes_from_file).and_return(
        [ UserInclude.new(filepath), UserInclude.new('widget.h') ]
      )

      result = subject.extract_user_includes_preprocess(
        name: 'test', filepath: filepath, preprocessed_filepath: '/build/directives_only/module.c'
      )

      expect(result.map(&:filename)).to eq(['widget.h'])
    end

  end


  # ===========================================================================
  describe '#extract_system_includes_preprocess' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    it 'delegates to the line-marker extractor with SYSTEM type and a practical max depth of 5' do
      expect(@preprocessinator_line_marker_includes_extractor).to receive(:extract_includes_from_file).with(
        '/build/directives_only/module.c',
        PreprocessinatorLineMarkerIncludesExtractor::SYSTEM,
        5
      ).and_return( [ SystemInclude.new('stdint.h') ] )

      result = subject.extract_system_includes_preprocess(
        name: 'test', filepath: filepath, preprocessed_filepath: '/build/directives_only/module.c'
      )

      expect(result.map(&:filename)).to eq(['stdint.h'])
    end

    it 'removes a self-referential entry matching the file being processed' do
      allow(@preprocessinator_line_marker_includes_extractor).to receive(:extract_includes_from_file).and_return(
        [ SystemInclude.new(filepath), SystemInclude.new('stdint.h') ]
      )

      result = subject.extract_system_includes_preprocess(
        name: 'test', filepath: filepath, preprocessed_filepath: '/build/directives_only/module.c'
      )

      expect(result.map(&:filename)).to eq(['stdint.h'])
    end

  end


  # ===========================================================================
  describe '#write_includes_list' do
  # ===========================================================================

    it 'dumps the includes list, converted to hashes, to the given filepath' do
      captured = nil
      allow(@yaml_wrapper).to receive(:dump) { |filepath, hashes| captured = [filepath, hashes] }

      subject.write_includes_list( '/build/includes/module.c.yml', [ UserInclude.new('widget.h') ] )

      expect(captured[0]).to eq('/build/includes/module.c.yml')
      expect(captured[1]).to eq( Includes.to_hashes( [ UserInclude.new('widget.h') ] ) )
    end

  end


  # ===========================================================================
  describe '#load_includes_list' do
  # ===========================================================================

    it 'loads and converts a hash list back into Include objects' do
      allow(@yaml_wrapper).to receive(:load).and_return(
        [ { 'type' => 'user', 'filepath' => 'widget.h' } ]
      )

      result = subject.load_includes_list( '/build/includes/module.c.yml' )

      expect(result.map(&:filename)).to eq(['widget.h'])
      expect(result.first).to be_a(UserInclude)
    end

    it 'treats nil YAML content (an empty cache file) as an empty list, not nil' do
      allow(@yaml_wrapper).to receive(:load).and_return(nil)

      result = subject.load_includes_list( '/build/includes/module.c.yml' )

      expect(result).to eq([])
    end

    it 'wraps a YamlLoadException with a clearer message, preserving reason/source/original_error' do
      original_error = StandardError.new('boom')
      allow(@yaml_wrapper).to receive(:load).and_raise(
        YamlLoadException.new( reason: :syntax, source: '/build/includes/module.c.yml', original_error: original_error, message: 'line 3: bad indentation' )
      )

      expect {
        subject.load_includes_list( '/build/includes/module.c.yml' )
      }.to raise_error do |error|
        expect(error).to be_a(YamlLoadException)
        expect(error.reason).to eq(:syntax)
        expect(error.source).to eq('/build/includes/module.c.yml')
        expect(error.original_error).to eq(original_error)
        expect(error.message).to match(/Cached #include list is corrupted or unreadable/)
        expect(error.message).to match(/line 3: bad indentation/)
      end
    end

  end

end
