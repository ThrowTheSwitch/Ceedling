# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for diff coverage, the share of a pull request's changed Ruby lines that tests
# execute.
#
# These specs live under tools/ rather than spec/ because spec/ ships inside the gem
# for certification self-tests while tools/ is excluded from it.

require_relative '../diff_coverage'

describe CiSummary::DiffCoverage do

  describe '.changed_lines' do
    it 'collects the added line numbers of each file from a zero-context diff' do
      diff = <<~DIFF
        diff --git a/lib/a.rb b/lib/a.rb
        --- a/lib/a.rb
        +++ b/lib/a.rb
        @@ -3,0 +4,2 @@ def x
        +one
        +two
        @@ -9 +11 @@
        -old
        +new
        diff --git a/bin/b.rb b/bin/b.rb
        --- a/bin/b.rb
        +++ b/bin/b.rb
        @@ -1,2 +1,0 @@
        -gone
        -gone
      DIFF

      expect(described_class.changed_lines( diff )).to eq( 'lib/a.rb' => [4, 5, 11] )
    end

    it 'skips a deleted file' do
      diff = "--- a/lib/a.rb\n+++ /dev/null\n@@ -1,2 +0,0 @@\n-x\n-y\n"

      expect(described_class.changed_lines( diff )).to eq( {} )
    end
  end

  describe '.measure' do
    let(:line_hits) do
      { 'lib/a.rb' => [nil, 1, 0, 0, 2, nil], 'plugins/p/lib/p.rb' => [0] }
    end

    it 'counts changed lines Ruby tracks and lists the uncovered ones as ranges' do
      changed = { 'lib/a.rb' => [1, 2, 3, 4, 5, 6], 'plugins/p/lib/p.rb' => [1] }

      expect(described_class.measure( changed: changed, line_hits: line_hits )).to eq(
        covered:   2,
        relevant:  5,
        uncovered: { 'lib/a.rb' => ['3-4'], 'plugins/p/lib/p.rb' => ['1'] }
      )
    end

    it 'ignores files outside the shipped Ruby and files coverage never tracked' do
      changed = { 'spec/a_spec.rb' => [1], 'lib/a.yml' => [1], 'lib/untracked.rb' => [1] }

      expect(described_class.measure( changed: changed, line_hits: line_hits )).to eq(
        covered: 0, relevant: 0, uncovered: {}
      )
    end
  end

  describe '.ranges' do
    it 'collapses consecutive line numbers' do
      expect(described_class.ranges( [7, 1, 2, 3, 9, 10] )).to eq( ['1-3', '7', '9-10'] )
    end
  end

end
