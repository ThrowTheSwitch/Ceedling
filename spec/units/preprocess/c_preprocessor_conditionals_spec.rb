# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/c_preprocessor_conditionals'

RSpec.describe CPreprocessorConditionals do

  # Helper: feed lines one at a time and collect active? state after each
  def active_states(tracker, *lines)
    lines.map do |line|
      tracker.process_directive(line)
      tracker.active?
    end
  end


  # ===========================================================================
  describe '#initialize / top-level active?' do
  # ===========================================================================

    it 'is active when no directives have been processed (outside all blocks)' do
      t = CPreprocessorConditionals.new([])
      expect(t.active?).to be true
    end

    it 'is active after only plain code lines' do
      t = CPreprocessorConditionals.new(['FOO'])
      t.process_directive('int x = 0;')
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe '#ifdef / #endif' do
  # ===========================================================================

    it 'is active inside #ifdef when macro is defined' do
      t = CPreprocessorConditionals.new(['MY_FEATURE'])
      t.process_directive('#ifdef MY_FEATURE')
      expect(t.active?).to be true
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'is inactive inside #ifdef when macro is not defined' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#ifdef MY_FEATURE')
      expect(t.active?).to be false
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'handles whitespace around the # and macro name' do
      t = CPreprocessorConditionals.new(['FOO'])
      t.process_directive('  #  ifdef   FOO  ')
      expect(t.active?).to be true
    end

    it 'is inactive inside #ifdef when defines list contains a different macro' do
      t = CPreprocessorConditionals.new(['OTHER'])
      t.process_directive('#ifdef MY_FEATURE')
      expect(t.active?).to be false
    end

    it 'strips -D prefix and =value suffix from defines' do
      t = CPreprocessorConditionals.new(['-DPREPROCESSING_TESTS=1', 'OTHER'])
      t.process_directive('#ifdef PREPROCESSING_TESTS')
      expect(t.active?).to be true
    end

    it 'strips bare =value suffix from defines (no -D)' do
      t = CPreprocessorConditionals.new(['FOO=42'])
      t.process_directive('#ifdef FOO')
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe '#ifndef / #endif' do
  # ===========================================================================

    it 'is active inside #ifndef when macro is NOT defined' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#ifndef MY_GUARD')
      expect(t.active?).to be true
    end

    it 'is inactive inside #ifndef when macro IS defined' do
      t = CPreprocessorConditionals.new(['MY_GUARD'])
      t.process_directive('#ifndef MY_GUARD')
      expect(t.active?).to be false
    end

  end


  # ===========================================================================
  describe '#if 0 and #if 1' do
  # ===========================================================================

    it 'is inactive inside #if 0' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 0')
      expect(t.active?).to be false
    end

    it 'is active inside #if 1' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 1')
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe '#if defined() / #if !defined()' do
  # ===========================================================================

    it 'is active for #if defined(MACRO) when macro is defined' do
      t = CPreprocessorConditionals.new(['FEATURE_X'])
      t.process_directive('#if defined(FEATURE_X)')
      expect(t.active?).to be true
    end

    it 'is inactive for #if defined(MACRO) when macro is not defined' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if defined(FEATURE_X)')
      expect(t.active?).to be false
    end

    it 'is active for #if !defined(MACRO) when macro is not defined' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if !defined(FEATURE_X)')
      expect(t.active?).to be true
    end

    it 'is inactive for #if !defined(MACRO) when macro is defined' do
      t = CPreprocessorConditionals.new(['FEATURE_X'])
      t.process_directive('#if !defined(FEATURE_X)')
      expect(t.active?).to be false
    end

    it 'handles spaces inside defined()' do
      t = CPreprocessorConditionals.new(['MY_MACRO'])
      t.process_directive('#if defined( MY_MACRO )')
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe 'complex / unrecognized #if — conservative treatment' do
  # ===========================================================================

    it 'treats complex #if expression as active (conservative)' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if VERSION >= 3')
      expect(t.active?).to be true
    end

    it 'treats #if with AND expression as active (conservative)' do
      t = CPreprocessorConditionals.new(['A'])
      t.process_directive('#if defined(A) && defined(B)')
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe '#else' do
  # ===========================================================================

    it 'activates #else when #ifdef was inactive' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#ifdef UNDEFINED')
      expect(t.active?).to be false
      t.process_directive('#else')
      expect(t.active?).to be true
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'deactivates #else when #ifdef was active' do
      t = CPreprocessorConditionals.new(['DEFINED'])
      t.process_directive('#ifdef DEFINED')
      expect(t.active?).to be true
      t.process_directive('#else')
      expect(t.active?).to be false
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'activates #else when #ifndef was inactive' do
      t = CPreprocessorConditionals.new(['GUARD'])
      t.process_directive('#ifndef GUARD')
      expect(t.active?).to be false
      t.process_directive('#else')
      expect(t.active?).to be true
    end

    it 'deactivates #else when #if 1 was active' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 1')
      t.process_directive('#else')
      expect(t.active?).to be false
    end

  end


  # ===========================================================================
  describe '#elif' do
  # ===========================================================================

    it 'activates #elif defined() when prior branch inactive and macro defined' do
      t = CPreprocessorConditionals.new(['FEATURE_B'])
      t.process_directive('#ifdef FEATURE_A')
      expect(t.active?).to be false
      t.process_directive('#elif defined(FEATURE_B)')
      expect(t.active?).to be true
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'stays inactive for #elif when prior branch was active' do
      t = CPreprocessorConditionals.new(['FEATURE_A', 'FEATURE_B'])
      t.process_directive('#ifdef FEATURE_A')
      expect(t.active?).to be true
      t.process_directive('#elif defined(FEATURE_B)')
      expect(t.active?).to be false
    end

    it 'stays inactive for #elif when macro not defined' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#ifdef FEATURE_A')
      t.process_directive('#elif defined(FEATURE_B)')
      expect(t.active?).to be false
    end

    it 'handles #elif 0' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 0')
      t.process_directive('#elif 0')
      expect(t.active?).to be false
    end

    it 'handles #elif 1' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 0')
      t.process_directive('#elif 1')
      expect(t.active?).to be true
    end

    it 'treats complex #elif as active when prior branch inactive (conservative)' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 0')
      t.process_directive('#elif VERSION > 3')
      expect(t.active?).to be true
    end

    it 'activates #else after #elif was inactive' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 0')
      t.process_directive('#elif 0')
      t.process_directive('#else')
      expect(t.active?).to be true
    end

    it 'deactivates #else after #elif was active' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#if 0')
      t.process_directive('#elif 1')
      t.process_directive('#else')
      expect(t.active?).to be false
    end

  end


  # ===========================================================================
  describe 'nesting' do
  # ===========================================================================

    it 'handles nested #ifdef correctly — inner inactive inside active outer' do
      t = CPreprocessorConditionals.new(['OUTER'])
      t.process_directive('#ifdef OUTER')
      expect(t.active?).to be true
      t.process_directive('#ifdef INNER')
      expect(t.active?).to be false
      t.process_directive('#endif')
      expect(t.active?).to be true
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'handles nested #ifdef inside inactive outer — inner stays inactive even if defined' do
      t = CPreprocessorConditionals.new(['INNER'])
      t.process_directive('#ifdef OUTER')
      expect(t.active?).to be false
      t.process_directive('#ifdef INNER')
      expect(t.active?).to be false  # outer inactive → inner also inactive
      t.process_directive('#endif')
      expect(t.active?).to be false
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

    it 'handles deeply nested blocks' do
      t = CPreprocessorConditionals.new(['A', 'B'])
      t.process_directive('#ifdef A')     # active
      t.process_directive('#ifdef B')     # active
      t.process_directive('#ifdef C')     # inactive (C not defined)
      expect(t.active?).to be false
      t.process_directive('#else')        # inactive->active
      expect(t.active?).to be true
      t.process_directive('#endif')
      expect(t.active?).to be true        # back to B block
      t.process_directive('#endif')
      expect(t.active?).to be true        # back to A block
      t.process_directive('#endif')
      expect(t.active?).to be true        # top level
    end

    it 'handles #else of inner block while outer is inactive' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#ifdef OUTER')  # inactive
      t.process_directive('#ifdef INNER')  # inactive (outer inactive)
      t.process_directive('#else')         # still inactive (outer still inactive)
      expect(t.active?).to be false
      t.process_directive('#endif')
      t.process_directive('#endif')
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe '#reset' do
  # ===========================================================================

    it 'clears state so the tracker can be reused' do
      t = CPreprocessorConditionals.new([])
      t.process_directive('#ifdef UNDEFINED')
      expect(t.active?).to be false
      t.reset
      expect(t.active?).to be true
    end

  end


  # ===========================================================================
  describe 'encoding safety' do
  # ===========================================================================

    it 'does not raise on lines with multi-byte UTF-8 characters' do
      t = CPreprocessorConditionals.new(['FOO'])
      expect {
        t.process_directive("/* © 2024 — résumé */")
        t.process_directive("#ifdef FOO  /* Ünïcödé comment */")
        t.process_directive("int x = 0;  // naïve code")
        t.process_directive('#endif')
      }.not_to raise_error
      # Active state after #endif is back to top-level true
      expect(t.active?).to be true
    end

    it 'correctly evaluates #ifdef on a line with non-ASCII in a trailing comment' do
      t = CPreprocessorConditionals.new(['FEATURE'])
      t.process_directive("#ifdef FEATURE  // © enabled")
      expect(t.active?).to be true
    end

    it 'does not crash on lines with invalid byte sequences after clean_encoding' do
      t = CPreprocessorConditionals.new([])
      # Simulate what clean_encoding produces from a line with invalid bytes
      mixed = "#ifdef SOME_MACRO".encode('UTF-8') + " \xFF".b.force_encoding('UTF-8')
      expect { t.process_directive(mixed.clean_encoding) }.not_to raise_error
    end

  end

end
