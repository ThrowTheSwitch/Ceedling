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

  let(:config) { { paths: { source: ['src/**'] } } }

  it 'accepts a build root of its own' do
    expect(BuildRootPolicy.problem( 'build', config )).to be_nil
  end

  # macOS spells /tmp/proj as /private/tmp/proj, and a project reached through any symlink
  # has two spellings
  it 'refuses the project directory or a directory above it spelled through a symlink', unless: Gem.win_platform? do
    File.symlink( File.join( @ws, 'proj' ), File.join( @ws, 'link' ) )

    expect(BuildRootPolicy.problem( File.join( @ws, 'link' ), config )).to eq( 'is the project directory or holds it' )
    expect(BuildRootPolicy.problem( File.join( @ws, 'link', 'src' ), config )).to eq( "holds 'src/**', which adds to a build" )
  end
end
