# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# ConfiguratorSetup#vendor_frameworks_and_support_files with a real FileWrapper on a real
# filesystem. A build brings build/vendor up to date with the gem's frameworks. It writes only
# a file that differs from its source, and replaces it whole by renaming a temporary copy over
# it, so a concurrent build never reads a half-written header (GH #1361). A transient copy
# fault, such as a path briefly the wrong type (GH #1292), is retried, and one that never
# clears names the destination.
#
# Faults are injected at FileWrapper#replace_file, the one write of each file, so the retry
# loop in FileWrapper#sync_tree is what runs.

require 'spec_helper'
require 'spec_integration_helper'
require 'ceedling/config/configurator_setup'
require 'ceedling/constants'

describe 'Vendor copy into build/vendor (integration)' do
  include IntegrationSpecHelpers

  # A real FileWrapper whose #replace_file raises for files beneath `fault_dir` the first
  # `raises_left` times. Named apart from other specs' faulting wrappers, since top-level
  # classes share one RSpec process.
  class ReplaceFaultingFileWrapper < FileWrapper
    def initialize(fault_dir:, raises_left: 1, error: Errno::EISDIR, **kwargs)
      super(**kwargs)
      @fault_dir = fault_dir
      @raises_left = raises_left
      @error = error
    end

    def replace_file(source, destination)
      if destination.start_with?( @fault_dir ) && @raises_left > 0
        @raises_left -= 1
        raise @error, "simulated transient type-mismatch on #{destination}"
      end
      super
    end
  end

  def file_wrapper(**fault)
    options = { loginator: IntegrationSpecHelpers::NULL, verbosinator: IntegrationSpecHelpers::NULL }
    return fault.empty? ? FileWrapper.new( options ) : ReplaceFaultingFileWrapper.new( **fault, **options )
  end

  def build_configurator_setup(file_wrapper)
    ConfiguratorSetup.new(
      configurator_builder:   IntegrationSpecHelpers::NULL,
      configurator_validator: IntegrationSpecHelpers::NULL,
      configurator_paths_validator: IntegrationSpecHelpers::NULL,
      loginator:              IntegrationSpecHelpers::NULL,
      reportinator:           IntegrationSpecHelpers::NULL,
      file_wrapper:           file_wrapper,
      system_wrapper:         IntegrationSpecHelpers::NULL,
      tool_executor:          IntegrationSpecHelpers::NULL
    )
  end

  # A stand-in for the gem's vendor/unity/src, with a nested file to show subdirectories copy
  def flattened_config(dir)
    unity_src = File.join( dir, 'gem_vendor', 'unity', 'src' )
    FileUtils.mkdir_p( File.join( unity_src, 'internal' ) )
    File.write( File.join( unity_src, 'unity.c' ), "// stand-in for unity.c\n" )
    File.write( File.join( unity_src, 'unity.h' ), "// stand-in for unity.h\n" )
    File.write( File.join( unity_src, 'internal', 'unity_internals.h' ), "// stand-in\n" )

    {
      # UNITY_LIB_PATH ('unity/src') joins this vendor root
      unity_vendor_path:               File.join( dir, 'gem_vendor' ),
      project_build_vendor_unity_path: File.join( dir, 'build', 'vendor', 'unity', 'src' ),
      project_use_mocks:               false,
      project_use_exceptions:          false,
      project_use_backtrace:           :none,
      project_use_partials:            false,
    }
  end

  def vendor(file_wrapper, dir, config)
    build_configurator_setup( file_wrapper ).vendor_frameworks_and_support_files( dir, config, test_build: true, release_build: false )
  end

  def snapshot(dest)
    return Dir.glob( File.join( dest, '**', '*' ) ).select { |path| File.file?( path ) }.to_h do |path|
      stat = File.stat( path )
      [path, [stat.ino, stat.mtime]]
    end
  end

  def leftovers(dest)
    return Dir.glob( File.join( dest, '**', '*' ), File::FNM_DOTMATCH ).select { |path| File.basename( path ).include?( '.tmp' ) }
  end

  it "copies every file, including those in subdirectories, into a fresh destination" do
    with_source_tree({}) do |dir|
      config = flattened_config( dir )
      dest = config[:project_build_vendor_unity_path]

      vendor( file_wrapper, dir, config )

      expect( File.read( File.join( dest, 'unity.h' ) ) ).to eq( "// stand-in for unity.h\n" )
      expect( File.exist?( File.join( dest, 'internal', 'unity_internals.h' ) ) ).to be(true)
      expect( leftovers( dest ) ).to be_empty
    end
  end

  it "rewrites nothing when the destination already matches" do
    with_source_tree({}) do |dir|
      config = flattened_config( dir )
      dest = config[:project_build_vendor_unity_path]
      vendor( file_wrapper, dir, config )
      before = snapshot( dest )
      sleep( 1.1 ) # Past the coarsest file modification time resolution

      vendor( file_wrapper, dir, config )

      expect( snapshot( dest ) ).to eq( before )
    end
  end

  it "restores an edited file by replacing it whole, and leaves matching files alone" do
    with_source_tree({}) do |dir|
      config = flattened_config( dir )
      dest = config[:project_build_vendor_unity_path]
      vendor( file_wrapper, dir, config )
      edited = File.join( dest, 'unity.h' )
      File.write( edited, "// an errant edit\n" )
      before = snapshot( dest )

      vendor( file_wrapper, dir, config )

      expect( File.read( edited ) ).to eq( "// stand-in for unity.h\n" )
      expect( File.stat( edited ).ino ).not_to eq( before[edited].first ) unless SystemWrapper.windows?
      untouched = File.join( dest, 'unity.c' )
      expect( snapshot( dest )[untouched] ).to eq( before[untouched] )
      expect( leftovers( dest ) ).to be_empty
    end
  end

  it "restores a missing file" do
    with_source_tree({}) do |dir|
      config = flattened_config( dir )
      dest = config[:project_build_vendor_unity_path]
      vendor( file_wrapper, dir, config )
      FileUtils.rm( File.join( dest, 'internal', 'unity_internals.h' ) )

      vendor( file_wrapper, dir, config )

      expect( File.exist?( File.join( dest, 'internal', 'unity_internals.h' ) ) ).to be(true)
    end
  end

  it "recovers from a transient copy failure instead of crashing the build" do
    with_source_tree({}) do |dir|
      config = flattened_config( dir )
      dest = config[:project_build_vendor_unity_path]

      expect { vendor( file_wrapper( fault_dir: dest, raises_left: 1 ), dir, config ) }.not_to raise_error

      expect( File.exist?( File.join( dest, 'unity.c' ) ) ).to be(true)
      expect( leftovers( dest ) ).to be_empty
    end
  end

  it "raises a clear, path-naming CeedlingException when the fault never clears" do
    with_source_tree({}) do |dir|
      config = flattened_config( dir )
      dest = config[:project_build_vendor_unity_path]

      expect {
        vendor( file_wrapper( fault_dir: dest, raises_left: 999 ), dir, config )
      }.to raise_error( CeedlingException, /#{Regexp.escape( dest )}/ )
    end
  end
end
