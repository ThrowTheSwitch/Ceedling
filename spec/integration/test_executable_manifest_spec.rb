# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The manifest Windows reads beside a test executable, written to disk by a real FileWrapper.
# Windows is stubbed so the file's on-disk shape is checked on every host.

require 'spec_helper'
require 'tmpdir'
require 'ceedling/constants'
require 'ceedling/file_wrapper'
require 'ceedling/generators/generator'

describe 'Test executable manifest (integration)' do
  let(:loginator)      { double( 'loginator' ).as_null_object }
  let(:verbosinator)   { double( 'verbosinator' ).as_null_object }
  let(:system_wrapper) { double( 'system_wrapper', windows?: true ) }

  let(:generator) do
    others = [
      :configurator, :generator_helper, :generator_mocks, :generator_test_results,
      :generator_test_results_backtrace, :generator_partials, :test_context_extractor,
      :tool_executor, :file_finder, :file_path_utils, :reportinator, :plugin_manager,
      :test_runner_manager
    ].to_h { |name| [name, double( name.to_s ).as_null_object] }

    Generator.new(
      others.merge(
        loginator:      loginator,
        system_wrapper: system_wrapper,
        file_wrapper:   FileWrapper.new( { loginator: loginator, verbosinator: verbosinator } )
      )
    )
  end

  it 'writes the manifest beside the test executable' do
    Dir.mktmpdir do |dir|
      executable = File.join( dir, 'test_setup_parser.exe' )
      generator.generate_test_executable_manifest( executable: executable, test_filepath: 'test/test_setup_parser.c' )

      manifest = File.join( dir, 'test_setup_parser.exe.manifest' )
      expect( File.exist?( manifest ) ).to be(true)
      expect( File.read( manifest ) ).to eq( TEST_EXECUTABLE_MANIFEST )
    end
  end

  it 'leaves an unchanged manifest untouched across builds' do
    Dir.mktmpdir do |dir|
      executable = File.join( dir, 'test_a.exe' )
      manifest   = "#{executable}.manifest"

      generator.generate_test_executable_manifest( executable: executable, test_filepath: 'test/test_a.c' )
      File.utime( Time.at( 0 ), Time.at( 0 ), manifest )
      generator.generate_test_executable_manifest( executable: executable, test_filepath: 'test/test_a.c' )

      expect( File.mtime( manifest ) ).to eq( Time.at( 0 ) )
    end
  end
end
