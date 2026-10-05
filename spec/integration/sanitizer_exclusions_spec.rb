# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Guards the `nosanitize` naming convention that keeps deliberately-faulty C
# fixtures out of ASan+UBSan instrumentation.
#
# The convention is enforceable only by a test, because every way it can break
# breaks silently. Renaming a crashing fixture without the segment instruments
# it, and the suite then reports a sanitizer "finding" that is really the fault
# the fixture exists to provoke. Breaking the matcher regex the other way
# instruments nothing at all, and the whole leg goes green while testing none of
# what it claims to.
#
# Integration tier rather than unit: this reads real files from
# assets/fixtures/, and unit specs in this repo touch neither filesystem nor
# shell. The matcher *logic* is pinned separately and purely in
# spec/units/config_matchinator_spec.rb.
#
# The one thing this cannot catch, stated plainly: a newly-added crashing
# fixture that carries neither the filename segment nor the convention comment
# is invisible to every check below. This guards drift in what is marked, not
# the absence of marking.

require 'spec_helper'
require 'yaml'

describe 'Sanitizer exclusion convention (integration)' do

  REPO_ROOT_FOR_SANITIZERS = File.expand_path( '../..', __dir__ )
  FIXTURES_DIR = File.join( REPO_ROOT_FOR_SANITIZERS, 'assets', 'fixtures' )
  FLAVORS_DIR  = File.join( REPO_ROOT_FOR_SANITIZERS, 'spec', 'support', 'system', 'sanitizers' )

  # Every fixture the convention must cover, by the name it carries today.
  # Listed explicitly, not globbed: a glob would quietly shrink to nothing if
  # these files were deleted or renamed, which is precisely the drift being
  # guarded against.
  EXCLUDED_FIXTURES = [
    'test_nosanitize_crash_sigsegv.c',
    'test_nosanitize_crash_sigsegv_with_param.c',
    'test_nosanitize_crash_assert.c',
    'test_nosanitize_ub_shift_overflow.c',
    'test_nosanitize_boom.c'
  ].freeze

  # The sentence each excluded fixture carries in a header comment. Short enough
  # to survive rewording of the surrounding prose, specific enough that no other
  # file would contain it by accident.
  CONVENTION_COMMENT = 'The `nosanitize` filename segment is read by a build-time matcher'

  # Read out of the flavor YAML rather than restated here, so this spec and the
  # mixins cannot drift apart -- a spec carrying its own copy of the regex would
  # keep passing after the mixin's copy was broken.
  def exclusion_regexes
    Dir[File.join( FLAVORS_DIR, '*.yml' )].sort.to_h do |path|
      hash = YAML.load_file( path )
      keys = [
        hash.dig( :flags, :test, :compile ),
        hash.dig( :flags, :test, :link ),
        hash.dig( :defines, :test )
      ].compact.flat_map( &:keys ).uniq

      expect( keys.size ).to eq(1), "#{File.basename(path)} must use one matcher throughout, found #{keys.inspect}"

      expr = keys.first.to_s
      expect( expr ).to start_with('/'), "#{File.basename(path)} matcher #{expr} is not in /regex/ form"
      expect( expr ).to end_with('/')

      [File.basename( path ), Regexp.new( expr[1..-2] )]
    end
  end

  it 'finds at least one sanitizer flavor to guard' do
    # Without this, every example below would vacuously pass if the flavor
    # directory were emptied or moved
    expect( exclusion_regexes ).not_to be_empty
  end

  it 'keeps every listed fixture present under its conventional name' do
    EXCLUDED_FIXTURES.each do |basename|
      expect( File.exist?( File.join( FIXTURES_DIR, basename ) ) ).to be(true),
        "#{basename} is missing. Deliberately-faulty fixtures must keep a `nosanitize` filename " \
        "segment -- it is what excludes them from sanitizer instrumentation. If this file was " \
        "renamed, update this list and the comment in the file itself; if it was deleted, remove " \
        "it from this list."
    end
  end

  it "excludes every listed fixture from every flavor's instrumentation" do
    exclusion_regexes.each do |flavor, regex|
      EXCLUDED_FIXTURES.each do |basename|
        expect( regex.match?( "test/#{basename}" ) ).to be(false),
          "#{flavor} would instrument #{basename}"
      end
    end
  end

  it 'still instruments ordinary test files' do
    # The other half of the regex's job. A pattern that excluded everything
    # would satisfy every example above while instrumenting nothing, and a green
    # suite would be indistinguishable from a working one.
    exclusion_regexes.each do |flavor, regex|
      ['test/test_example_file.c', 'build/test/runners/test_example_file_runner.c'].each do |filepath|
        expect( regex.match?( filepath ) ).to be(true), "#{flavor} would not instrument #{filepath}"
      end
    end
  end

  it 'keeps filename segment and convention comment in agreement, both directions' do
    named    = Dir[File.join( FIXTURES_DIR, '**', '*nosanitize*' )].sort
    commented = Dir[File.join( FIXTURES_DIR, '**', '*.c' )].sort.select do |path|
      File.read( path ).include?( CONVENTION_COMMENT )
    end

    # Either direction failing means a reader of one signal is being misled by
    # the absence of the other
    expect( named.sort ).to eq(commented.sort)
  end

end
