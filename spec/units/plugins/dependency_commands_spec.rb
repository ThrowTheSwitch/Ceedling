# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/dependencies/lib', __dir__ ) )

require 'dependency_spec'
require 'dependency_commands'

# Every command is built by a stand-in builder that records the tool and arguments it was
# given, so these specs check what would run without running anything
describe DependencyCommands do

  let(:tools) do
    { zip: { name: 'zip' }, tar_gzip: { name: 'tar' }, git_clone: { name: 'clone' },
      git_checkout: { name: 'checkout' }, subversion: { name: 'svn' } }
  end

  let(:builder) { ->( tool, *args ) { [tool[:name], *[tool[:executable]].compact, *Array( tool[:arguments] ), *args] } }
  let(:commands) { described_class.new( tools: tools, builder: builder ) }

  def spec_for(fetch: nil, build: [])
    return DependencySpec.build_all( [{ name: 'dep', fetch: fetch, build: build }] ).first
  end

  describe '#fetch' do
    it 'fetches nothing without a method or with :none' do
      expect(commands.fetch( spec_for )).to be_empty
      expect(commands.fetch( spec_for( fetch: { method: :none } ) )).to be_empty
    end

    it 'unpacks archives from their source' do
      expect(commands.fetch( spec_for( fetch: { method: :zip, source: 'a.zip' } ) )).to eq( [['zip', 'a.zip']] )
      expect(commands.fetch( spec_for( fetch: { method: :tar_gzip, source: 'a.tgz' } ) )).to eq( [['tar', 'a.tgz']] )
    end

    it 'shallow clones a git repository, on a tag or branch when given' do
      expect(commands.fetch( spec_for( fetch: { method: :git, source: 'url' } ) )).to eq( [['clone', '', '--depth 1', 'url']] )
      expect(commands.fetch( spec_for( fetch: { method: :git, source: 'url', branch: 'dev' } ) )).to eq( [['clone', '-b dev', '--depth 1', 'url']] )
      expect(commands.fetch( spec_for( fetch: { method: :git, source: 'url', tag: 'v1', branch: 'dev' } ) )).to eq( [['clone', '-b v1', '--depth 1', 'url']] )
    end

    it 'fully clones a git repository, then checks out a commit hash' do
      expect(commands.fetch( spec_for( fetch: { method: :git, source: 'url', hash: 'abc123' } ) )).to eq(
        [['clone', '', '', 'url'], ['checkout', 'abc123']]
      )
    end

    it 'checks out a subversion repository, at a revision when given' do
      expect(commands.fetch( spec_for( fetch: { method: :svn, source: 'url' } ) )).to eq( [['svn', '', 'url']] )
      expect(commands.fetch( spec_for( fetch: { method: :svn, source: 'url', revision: '42' } ) )).to eq( [['svn', '--revision 42', 'url']] )
    end

    it 'runs each custom command as given' do
      fetch = { method: :custom, executable: ['curl -o a.zip https://x', 'unzip  "a b.zip"'] }

      expect(commands.fetch( spec_for( fetch: fetch ) )).to eq(
        [['Dependencies custom command #1', 'curl', '-o a.zip https://x'], ['Dependencies custom command #2', 'unzip', '"a b.zip"']]
      )
    end
  end

  it 'runs a single custom command given as a string' do
    expect(commands.fetch( spec_for( fetch: { method: :custom, executable: 'curl -O https://x' } ) )).to eq(
      [['Dependencies custom command #1', 'curl', '-O https://x']]
    )
  end

  describe '#build' do
    it 'turns each build command into a command, leaving built-in steps as symbols' do
      expect(commands.build( spec_for( build: ['./configure --prefix "/opt/a  b"', :build_lib, 'make'] ) )).to eq(
        [['./configure', './configure', '--prefix "/opt/a  b"'], :build_lib, ['make', 'make']]
      )
    end
  end

end
