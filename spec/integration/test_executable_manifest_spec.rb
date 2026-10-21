# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The manifest Windows reads beside a test executable, written to disk by a real FileWrapper.
# Windows is stubbed so the file's on-disk shape is checked on every host. Whether Windows
# honors it is checked only on a Windows host where Installer Detection is active.

require 'spec_helper'
require 'spec_integration_helper'
require 'open3'
require 'tmpdir'
require 'ceedling/constants'
require 'ceedling/file_wrapper'
require 'ceedling/generators/generator'
require 'ceedling/system_wrapper'
require 'fileutils'

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

  # Installer Detection itself, on a Windows host where it is active. MinGW-w64 GCC links a
  # default manifest that already requests the invoker's rights, and Windows ignores a
  # manifest file beside an executable embedding one, so the default is displaced first.
  context 'on Windows, an executable named like an installer' do
    include_context 'requires gcc'
    before { skip 'Installer Detection is a Windows behavior' unless SystemWrapper.windows? }

    # Displaces GCC's default manifest object, which it links only when found on its search path
    def build(dir, name)
      File.write( File.join( dir, 'empty.c' ), "int ceedling_no_default_manifest;\n" )
      File.write( File.join( dir, 'main.c' ), "int main(void) { return 0; }\n" )
      run( "gcc -c #{File.join( dir, 'empty.c' )} -o #{File.join( dir, 'default-manifest.o' )}" )

      executable = File.join( dir, "#{name}.exe" )
      run( "gcc -B#{dir}/ #{File.join( dir, 'main.c' )} -o #{executable}" )
      return executable
    end

    def run(command)
      output, status = Open3.capture2e( command )
      raise "#{command}\n#{output}" unless status.success?
    end

    def embeds_manifest?(executable)
      return File.binread( executable ).include?( 'requestedExecutionLevel' )
    end

    # Windows refuses to start it (ERROR_ELEVATION_REQUIRED, 740), which Ruby raises
    def starts?(executable)
      _output, status = Open3.capture2e( executable )
      return status.success?
    rescue SystemCallError
      return false
    end

    it 'runs only with the manifest beside it' do
      Dir.mktmpdir do |dir|
        # Windows caches its decision per executable, so each check runs its own copy
        bare = build( dir, 'test_update_bare' )
        skip 'this toolchain embeds a manifest despite the displaced default' if embeds_manifest?( bare )
        skip 'Installer Detection is not active on this host' if starts?( bare )

        manifested = File.join( dir, 'test_update_manifested.exe' )
        FileUtils.cp( bare, manifested )
        generator.generate_test_executable_manifest( executable: manifested, test_filepath: 'test/test_update.c' )

        expect( starts?( manifested ) ).to be(true)
      end
    end
  end
end
