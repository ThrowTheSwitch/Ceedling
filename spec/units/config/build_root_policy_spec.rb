# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/config/build_root_policy'

# The path handling audit around GH #1370: clobber empties the build root's test and release
# trees, so a build root holding the project's own files is refused however it is spelled
describe BuildRootPolicy do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @ws = File.realpath( dir )
      FileUtils.mkdir_p( File.join( @ws, 'proj', 'src' ) )
      Dir.chdir( File.join( @ws, 'proj' ) ) { example.run }
    end
  end

  it 'accepts a build root of its own' do
    expect(BuildRootPolicy.problem( 'build' )).to be_nil
  end

  # macOS spells /tmp/proj as /private/tmp/proj, and a project reached through any symlink
  # has two spellings
  it 'refuses the project directory or a directory above it, but no directory below it, spelled through a symlink', unless: Gem.win_platform? do
    File.symlink( File.join( @ws, 'proj' ), File.join( @ws, 'link' ) )

    expect(BuildRootPolicy.problem( File.join( @ws, 'link' ) )).to eq( 'is the project directory or holds it' )
    expect(BuildRootPolicy.problem( File.join( @ws, 'link', 'src' ) )).to be_nil
  end

  it 'names each :paths and :files entry that adds to a build from within the build root' do
    config = { paths: { source: ['src/**', 'build/gen/**', '-:build/old'] }, files: { include: ['+:build/gen/table.h'] } }

    expect(BuildRootPolicy.entries_within( 'build', config )).to eq( [[:paths, :source, 'build/gen/**'], [:files, :include, '+:build/gen/table.h']] )
    expect(BuildRootPolicy.entries_within( 'out', config )).to be_empty
  end

  it 'names the directories Ceedling and its enabled plugins create' do
    config = {
      project_build_root: 'build', project_build_artifacts_root: 'build/artifacts', project_build_tests_root: 'build/test',
      project_build_release_root: 'build/release', project_build_vendor_root: 'build/vendor',
      project_build_dependencies_cache_path: 'build/cache', project_log_path: 'build/logs', cmock_mock_path: 'mocks',
      plugins_enabled: ['gcov', 'report_tests_pretty_stdout']
    }

    expect(BuildRootPolicy.reserved( config )).to contain_exactly(
      'build/artifacts', 'build/test', 'build/release', 'build/vendor', 'build/cache', 'build/logs', 'mocks', 'build/gcov', 'build/report_tests_pretty_stdout'
    )
  end

  # An empty path would name the project directory itself
  it 'names no directory for a setting with no path' do
    expect(BuildRootPolicy.reserved( { project_log_path: '', plugins_enabled: ['gcov'] } )).to be_empty
  end
end
