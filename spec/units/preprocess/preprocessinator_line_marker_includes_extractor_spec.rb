# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator_line_marker_includes_extractor'
require 'ceedling/includes/includes'

# Built entirely on #extract_includes_from_string -- a StringIO wrapper around the
# same private #extract_includes every production call eventually reaches, so no
# real files or fixtures are needed for full coverage of this parser's branching.
describe PreprocessinatorLineMarkerIncludesExtractor do
  before(:each) do
    @include_factory = double('include_factory')
    @file_wrapper     = double('file_wrapper')

    allow(@include_factory).to receive(:user_include_from_filepath) do |filepath, test: nil|
      UserInclude.new(filepath)
    end
    allow(@include_factory).to receive(:system_include_from_filepath) do |filepath|
      SystemInclude.new(filepath)
    end

    @extractor = described_class.new(
      :include_factory => @include_factory,
      :file_wrapper    => @file_wrapper
    )
  end

  def paths_of(includes)
    includes.map(&:filepath)
  end

  describe '#extract_includes_from_string' do
    it 'raises for an invalid type argument' do
      expect {
        @extractor.extract_includes_from_string( "# 1 \"test.c\"\n", 'test.c', :bogus )
      }.to raise_error( CeedlingException, /Invalid type argument/ )
    end

    it 'skips <built-in> and <command-line> markers regardless of initial-file state' do
      content = <<~OUTPUT
        # 1 "<built-in>"
        # 1 "<command-line>" 2
        # 1 "test.c"
        # 1 "widget.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
    end

    it 'ignores line markers before the initial file is found, even at line 1' do
      # A `# 1` marker for some other file (e.g. from an early command-line define)
      # must not be mistaken for the real source file's own opening marker.
      content = <<~OUTPUT
        # 1 "something_else.h"
        # 1 "test.c"
        # 1 "widget.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
    end

    it 'extracts only non-system (flag 3 absent) includes for USER type' do
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
        # 1 "/usr/include/stdint.h" 1 3 4
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
      expect( includes.first ).to be_a( UserInclude )
    end

    it 'extracts only system (flag 3 present) includes for SYSTEM type' do
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
        # 1 "/usr/include/stdint.h" 1 3 4
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::SYSTEM )

      expect( paths_of(includes) ).to eq( ['/usr/include/stdint.h'] )
      expect( includes.first ).to be_a( SystemInclude )
    end

    it 'threads the test: keyword argument into user_include_from_filepath' do
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
      OUTPUT

      expect(@include_factory).to receive(:user_include_from_filepath).with('widget.h', test: 'test_widget')

      @extractor.extract_includes_from_string( content, 'test.c', described_class::USER, test: 'test_widget' )
    end

    it 'increments depth entering a nested file and decrements when returning' do
      # widget.h (depth 2) includes nested.h (depth 3); control then returns to
      # test.c (flag 2, depth back to 1) before a sibling top-level include
      # (also depth 2) -- confirms depth tracking survives a return.
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
        # 1 "nested.h" 1
        # 9 "widget.h" 2
        # 2 "test.c" 2
        # 1 "sibling.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h', 'nested.h', 'sibling.h'] )
    end

    it 'excludes a file beyond max_depth while keeping shallower ones' do
      # The source file itself is depth 1, so its own top-level includes (widget.h)
      # are depth 2 -- max_depth: 2 keeps those while excluding anything nested deeper.
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
        # 1 "nested.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER, 2 )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
    end

    it 'applies no depth limit when max_depth is nil' do
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
        # 1 "nested.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER, nil )

      expect( paths_of(includes) ).to eq( ['widget.h', 'nested.h'] )
    end

    it 'collapses a .. segment GCC leaves uncanonicalized in a directory-relative quoted include line marker' do
      # GCC forms a directory-relative quoted include's line marker as the including
      # file's own directory concatenated with the literal include text -- it does not
      # canonicalize away a .. this produces. Left uncanonicalized, this candidate could
      # never correspond to the project's own, real, ..-free file list downstream.
      content = <<~OUTPUT
        # 1 "test/unit/test_dotdot.c"
        # 1 "test/unit/../common/helper.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test/unit/test_dotdot.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['test/common/helper.h'] )
    end

    it 'deduplicates a path reached more than once (e.g. via an include guard)' do
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "shared.h" 1
        # 2 "test.c" 2
        # 1 "shared.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['shared.h'] )
    end
  end

  describe '#extract_includes_from_file' do
    it 'opens the file in binary mode and extracts the same way as from a string' do
      # The initial-marker match is by basename against the filepath argument itself
      # (there is no separate "original source" argument) -- the fixture path here
      # must share a basename with the marker for extraction to find its start.
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
      OUTPUT

      allow(@file_wrapper).to receive(:open).with('build/test.c', 'rb').and_yield( StringIO.new(content) )

      includes = @extractor.extract_includes_from_file( 'build/test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
    end

    it 'wraps an underlying failure in a CeedlingException identifying the file and type' do
      allow(@file_wrapper).to receive(:open).and_raise( StandardError.new('file vanished') )

      expect {
        @extractor.extract_includes_from_file( 'directives_only.txt', described_class::SYSTEM )
      }.to raise_error( CeedlingException, /directives_only\.txt/ )
    end
  end
end
