# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'spec_integration_helper'
require 'partial_files_harness'
require 'dependency_tracker_integration_helper'

# Stage 7 across successive builds, with a real compiler and dependency tracker. The
# unit specs fix each decision with stand-ins. These prove the decisions hold together: what
# one build records is what the next build trusts.
describe 'Partial file preprocessing (integration)' do
  include_context 'requires gcc'
  include DependencyTrackerIntegrationHelper

  before(:each) { skip 'requires -fdirectives-only support' unless directives_only_supported? }

  # A module whose storage class comes from a macro in a header its source includes
  WIDGET_TREE = {
    'src/config.h' => "#ifndef CONFIG_H\n#define CONFIG_H\n#define PRIVATE static\n#endif\n",
    'src/widget.h' => "#ifndef WIDGET_H\n#define WIDGET_H\n#include \"config.h\"\nint widget_get(void);\n#endif\n",
    'src/widget.c' => "#include \"widget.h\"\nPRIVATE int helper(void) { return 41; }\nint widget_get(void) { return helper() + 1; }\n"
  }.freeze

  def in_project
    with_source_tree( WIDGET_TREE ) do |dir|
      Dir.chdir( dir ) { yield }
    end
  end

  def harness(**options)
    IntegrationSpecHelpers::PartialFilesHarness.new( **options )
  end

  # One build of `filepath` by `with`, against a dependency store that persists between builds
  def build(filepath = 'src/widget.c', with: harness)
    return with.run_source( filepath, tracker: build_dependency_tracker( store_path: 'build/dependencies.yml' ) )
  end

  def past
    return Time.at( 1_000_000_000 )
  end

  def backdate(paths)
    File.utime( past, past, *paths )
  end

  def expanded(config)
    File.read( config.expansion_filepath )
  end

  it 'records every file a build writes, and the next build recalls the same record without running' do
    in_project do
      first  = build
      paths  = harness.artifact_paths( 'src/widget.c' )

      expect( first ).to have_attributes(
        raw_directives_only_filepath: paths[:raw_directives_only], fallback: false,
        raw_expansion_filepath: paths[:raw_expansion], expansion_filepath: paths[:expanded_code]
      )
      expect( expanded( first ) ).to include( 'static int helper(void)' )
      expect( File.read( first.raw_expansion_filepath ) ).to match( /^# \d+ "src\/config\.h"/ )

      # A recalled record that ran nothing leaves every file exactly as it was. The files are
      # dated back first, so a rewrite shows whatever the filesystem's mtime resolution.
      files = paths.values + [first.assembled_filepath]
      backdate( files )
      second = build

      expect( second.to_h ).to eq( first.to_h )
      expect( files.map { |path| File.mtime( path ) } ).to all( eq( past ) )
    end
  end

  # The macro lives in a header the module includes, never in the module itself
  it 'preprocesses again when a header the expansion entered changes' do
    in_project do
      expect( expanded( build ) ).to include( 'static int helper(void)' )

      File.write( 'src/config.h', "#ifndef CONFIG_H\n#define CONFIG_H\n#define PRIVATE\n#endif\n" )

      code = expanded( build )
      expect( code ).to include( 'int helper(void)' )
      expect( code ).to_not include( 'static' )
    end
  end

  # Only the full expansion meets the broken macro. Restoring the header is the one change
  # before the next build, so only what the failed build left behind can make it expand again.
  it 'leaves no expansion behind when the full expansion fails, and expands on the next build' do
    in_project do
      build
      paths  = harness.artifact_paths( 'src/widget.c' )
      config = File.read( 'src/config.h' )

      File.write( 'src/config.h', config.sub( '#define PRIVATE static', "#define WRAP(x) x\n#define PRIVATE WRAP(static" ) )
      record = build

      expect( record ).to have_attributes( expansion_filepath: nil, raw_expansion_filepath: nil )
      expect( paths.values_at( :raw_expansion, :expanded_code ).select { |path| File.exist?( path ) } ).to be_empty

      File.write( 'src/config.h', config )
      expect( expanded( build ) ).to include( 'static int helper(void)' )
    end
  end

  # An earlier build's raw copy must not pass for this file being preprocessed accurately
  it 'records fallback for a file whose directives-only run fails, and recalls it on the next build' do
    in_project do
      expect( build.fallback ).to be( false )

      failing = harness( directives_only_tool: IntegrationSpecHelpers.failing_tool( DEFAULT_TEST_FILE_DIRECTIVES_ONLY_PREPROCESSOR_TOOL ) )
      File.write( 'src/widget.c', File.read( 'src/widget.c' ) + "\n" )

      record = build( with: failing )
      expect( record ).to have_attributes( fallback: true, raw_directives_only_filepath: nil )

      # The next build recalls that record, rewriting nothing
      backdate( [record.assembled_filepath] )
      expect( build( with: failing ) ).to have_attributes( fallback: true, raw_directives_only_filepath: nil )
      expect( File.mtime( record.assembled_filepath ) ).to eq( past )
    end
  end
end
