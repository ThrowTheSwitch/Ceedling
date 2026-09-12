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

    # #1268: GCC's -fdirectives-only output preserves the ORIGINAL indentation of a
    # top-level #include when it replaces that directive with a line marker entering
    # the included file -- an indented `    #include "widget.h"` produces an indented
    # `    # 1 "widget.h" 1`, not the flush-left marker every other marker GCC
    # generates uses. LINE_MARKER_REGEX must recognize that marker too, or the include
    # is silently missing from the extracted list entirely.
    it 'recognizes a line marker that is itself indented (e.g. from an indented #include)' do
      content = <<~OUTPUT
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

    it 'collapses a .. segment even when GCC emits an absolute marker path' do
      # PathMatcher.resolve_relative deliberately leaves an ABSOLUTE query's own ..
      # untouched (its documented contract defers that case to File.expand_path-based
      # comparison elsewhere) -- reachable here whenever the file actually being
      # preprocessed has an absolute path of its own, which makes GCC's own marker
      # text for a directory-relative include absolute too. Left uncanonicalized (as
      # it was before this test), the marker's own literal '..' segment can never
      # correspond to the project's real, ..-free file list downstream, and the
      # include silently vanishes.
      content = <<~OUTPUT
        # 1 "/proj/test/unit/test_dotdot.c"
        # 1 "/proj/test/unit/../common/helper.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, '/proj/test/unit/test_dotdot.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['/proj/test/common/helper.h'] )
    end

    it 'collapses a .. segment in an absolute Windows drive-letter marker path, preserving the drive letter' do
      # Collapsed with a plain segment walk, not File.expand_path -- which is
      # CWD/drive-dependent and would silently inject the CURRENT process's own
      # drive letter here instead of preserving this marker's own "C:".
      content = <<~OUTPUT
        # 1 "C:\\proj\\test\\unit\\test_dotdot.c"
        # 1 "C:\\proj\\test\\unit\\..\\common\\helper.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'C:\\proj\\test\\unit\\test_dotdot.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['C:/proj/test/common/helper.h'] )
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

  describe '#resolve_computed_includes' do
    # Correlates `-fdirectives-only` entering markers back to the raw source lines
    # that produced them. Used to recover GCC's own resolution of a macro-target
    # `#include` -- the directive has no literal filename to scan for, but the
    # accurate pass still opens the header and emits an ordinary entering marker.

    def resolve(content, basename, lines)
      allow(@file_wrapper).to receive(:open_with_retry).with('donly.c', 'rb').and_yield( StringIO.new(content) )
      @extractor.resolve_computed_includes(
        preprocessed_filepath: 'donly.c', source_basename: basename, source_lines: lines
      )
    end

    it 'returns an empty hash (and reads nothing) when no source lines are wanted' do
      expect(@file_wrapper).to_not receive(:open_with_retry)
      expect(
        @extractor.resolve_computed_includes(
          preprocessed_filepath: 'donly.c', source_basename: 'foo.c', source_lines: []
        )
      ).to eq({})
    end

    it 'maps a wanted source line to the path GCC entered at that line' do
      # foo.c line 3 carries the computed #include; the marker replaces that line, so
      # the running source-line counter still reads 3 when the entering marker appears.
      content = <<~OUTPUT
        # 1 "foo.c"
        int a;
        int b;
        # 1 "device.h" 1

        typedef int dev_t;
        # 4 "foo.c" 2
        int c;
      OUTPUT

      expect( resolve(content, 'foo.c', [3]) ).to eq( { 3 => 'device.h' } )
    end

    it 'ignores an entering marker attributed to a line that was not asked about' do
      content = <<~OUTPUT
        # 1 "foo.c"
        int a;
        # 1 "literal.h" 1
        # 3 "foo.c" 2
        int c;
      OUTPUT

      expect( resolve(content, 'foo.c', [99]) ).to eq( {} )
    end

    it 'does not let another file\'s own nested markers or body drift the source-line counter' do
      # Two computed includes, on lines 1 and 3. device_a.h itself includes inner.h;
      # neither inner.h's marker nor any non-target body line may advance the count,
      # or the line-3 correlation lands wrong.
      content = <<~OUTPUT
        # 1 "foo.c"
        # 1 "device_a.h" 1
        # 1 "inner.h" 1
        deep stuff
        more deep stuff
        # 2 "device_a.h" 2
        shallow stuff
        # 2 "foo.c" 2
        int x;
        # 1 "device_b.h" 1
        # 3 "foo.c" 2
        int y;
      OUTPUT

      expect( resolve(content, 'foo.c', [1, 3]) ).to eq(
        { 1 => 'device_a.h', 3 => 'device_b.h' }
      )
    end

    it 'skips <built-in> / <command-line> markers without disturbing correlation' do
      content = <<~OUTPUT
        # 1 "<built-in>"
        # 1 "<command-line>" 2
        # 1 "foo.c"
        int a;
        int b;
        # 1 "device.h" 1
        # 3 "foo.c" 2
      OUTPUT

      expect( resolve(content, 'foo.c', [3]) ).to eq( { 3 => 'device.h' } )
    end

    it 'reports nothing for a wanted line whose computed include produced no entering marker' do
      # e.g. the guard around it evaluated false, or the target was already included.
      content = <<~OUTPUT
        # 1 "foo.c"
        int a;
        int b;

        int c;
      OUTPUT

      expect( resolve(content, 'foo.c', [3]) ).to eq( {} )
    end

    it 'collapses an uncanonicalized .. in the entered path, matching the other marker walk' do
      content = <<~OUTPUT
        # 1 "test/unit/foo.c"
        a;
        # 1 "test/unit/../common/dev.h" 1
        # 3 "test/unit/foo.c" 2
      OUTPUT

      expect( resolve(content, 'foo.c', [2]) ).to eq( { 2 => 'test/common/dev.h' } )
    end

    it 'wraps an underlying read failure in a CeedlingException naming the file' do
      allow(@file_wrapper).to receive(:open_with_retry).and_raise( StandardError.new('gone') )

      expect {
        @extractor.resolve_computed_includes(
          preprocessed_filepath: 'donly.c', source_basename: 'foo.c', source_lines: [1]
        )
      }.to raise_error( CeedlingException, /donly\.c/ )
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

      allow(@file_wrapper).to receive(:open_with_retry).with('build/test.c', 'rb').and_yield( StringIO.new(content) )

      includes = @extractor.extract_includes_from_file( 'build/test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
    end

    it 'wraps an underlying failure in a CeedlingException identifying the file and type' do
      allow(@file_wrapper).to receive(:open_with_retry).and_raise( StandardError.new('file vanished') )

      expect {
        @extractor.extract_includes_from_file( 'directives_only.txt', described_class::SYSTEM )
      }.to raise_error( CeedlingException, /directives_only\.txt/ )
    end
  end
end
