# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator_line_marker_includes_extractor'
require 'ceedling/includes/includes'

# Regression coverage for GH #1268 only -- this class otherwise has no unit spec on this
# branch. Built on #extract_includes_from_string, a StringIO wrapper around the same
# private #extract_includes every production call eventually reaches.
describe PreprocessinatorLineMarkerIncludesExtractor do
  before(:each) do
    @include_factory = double('include_factory')

    allow(@include_factory).to receive(:user_include_from_filepath) do |filepath|
      UserInclude.new(filepath)
    end
    allow(@include_factory).to receive(:system_include_from_filepath) do |filepath|
      SystemInclude.new(filepath)
    end

    @extractor = described_class.new(
      :include_factory => @include_factory
    )
  end

  def paths_of(includes)
    includes.map(&:filepath)
  end

  describe '#extract_includes_from_string' do
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

    it 'still recognizes an ordinary, flush-left line marker' do
      content = <<~OUTPUT
        # 1 "test.c"
        # 1 "widget.h" 1
      OUTPUT

      includes = @extractor.extract_includes_from_string( content, 'test.c', described_class::USER )

      expect( paths_of(includes) ).to eq( ['widget.h'] )
    end
  end
end
