# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/dependencies/dependency_differ'

describe DependencyDiffer do

  subject(:differ) { described_class.new }

  describe '#diff_content' do
    it 'reports a reason instead of a diff when no snapshot was ever captured' do
      result = differ.diff_content( nil, "new content\n" )

      expect( result ).to have_key('reason')
      expect( result['reason'] ).to match(/no prior snapshot/i)
      expect( result ).not_to have_key('diff')
    end

    it "reports a reason when the prior snapshot's content was truncated" do
      snapshot = { 'truncated' => true, 'size' => 99 }

      result = differ.diff_content( snapshot, "new content\n" )

      expect( result['reason'] ).to match(/truncated/i)
    end

    it 'reports a reason when the prior snapshot has no content field (captured at tier :meta, not :full)' do
      snapshot = { 'path' => 'foo.h', 'hash' => 'abc', 'meta' => { 'a' => 1 } }

      result = differ.diff_content( snapshot, "new content\n" )

      expect( result['reason'] ).to match(/did not include content/i)
    end

    it 'reports a reason when the file no longer exists (new_content is nil)' do
      snapshot = { 'content' => "old content\n" }

      result = differ.diff_content( snapshot, nil )

      expect( result['reason'] ).to match(/no longer exists/i)
    end

    it 'produces a readable line-level diff for changed text content' do
      snapshot = { 'content' => "line one\nline two\nline three\n" }

      result = differ.diff_content( snapshot, "line one\nline TWO\nline three\n" )

      expect( result ).to have_key('diff')
      expect( result['diff'] ).to include('line two')
      expect( result['diff'] ).to include('line TWO')
      # Unchanged lines are not noise in the output.
      expect( result['diff'] ).not_to include('line one')
      expect( result['diff'] ).not_to include('line three')
    end

    it 'shows an addition as a plain + line' do
      snapshot = { 'content' => "a\n" }

      result = differ.diff_content( snapshot, "a\nb\n" )

      expect( result['diff'] ).to include('+')
      expect( result['diff'] ).to include('b')
    end

    it 'shows a removal as a plain - line' do
      snapshot = { 'content' => "a\nb\n" }

      result = differ.diff_content( snapshot, "a\n" )

      expect( result['diff'] ).to include('-')
      expect( result['diff'] ).to include('b')
    end

    it 'reports a byte-size summary instead of a line diff for binary content' do
      snapshot = { 'content' => "abc\x00def" }

      result = differ.diff_content( snapshot, "abc\x00defgh" )

      expect( result ).to have_key('summary')
      expect( result['summary'] ).to match(/binary/i)
      expect( result ).not_to have_key('diff')
    end

    it 'treats content as binary if either side contains a null byte' do
      snapshot = { 'content' => "plain text" }

      result = differ.diff_content( snapshot, "now\x00binary" )

      expect( result ).to have_key('summary')
    end
  end

  describe '#diff_meta' do
    it 'reports a reason instead of a diff when no prior meta snapshot exists' do
      result = differ.diff_meta( nil, { 'a' => 1 } )

      expect( result['reason'] ).to match(/no prior meta snapshot/i)
    end

    it 'reports keys present only in the new meta as added' do
      result = differ.diff_meta( { 'a' => 1 }, { 'a' => 1, 'b' => 2 } )

      expect( result['added'] ).to eq( 'b' => 2 )
      expect( result['removed'] ).to eq( {} )
      expect( result['changed_keys'] ).to eq( {} )
    end

    it 'reports keys present only in the old meta as removed' do
      result = differ.diff_meta( { 'a' => 1, 'b' => 2 }, { 'a' => 1 } )

      expect( result['removed'] ).to eq( 'b' => 2 )
    end

    it 'reports keys present in both with different values as changed, with old and new' do
      result = differ.diff_meta( { 'opt_level' => 0 }, { 'opt_level' => 2 } )

      expect( result['changed_keys'] ).to eq( 'opt_level' => { 'old' => 0, 'new' => 2 } )
    end

    it 'does not report an unchanged key in any category' do
      result = differ.diff_meta( { 'a' => 1 }, { 'a' => 1 } )

      expect( result['added'] ).to eq( {} )
      expect( result['removed'] ).to eq( {} )
      expect( result['changed_keys'] ).to eq( {} )
    end

    it 'handles a nil old_meta or new_meta as an empty Hash rather than raising' do
      expect { differ.diff_meta( {}, nil ) }.not_to raise_error
      expect( differ.diff_meta( {}, nil )['removed'] ).to eq( {} )
    end
  end

end
