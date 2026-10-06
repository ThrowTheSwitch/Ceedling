# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for assembling the component model from already-parsed inputs.
#
# Inventory is where the facts about a Ceedling gem become components. It receives
# plain values rather than reading anything, so these specs pass hashes and arrays
# where production passes what sources.rb collected.

require_relative '../inventory'
require_relative '../submodules'

describe Sbom::Inventory do

  SUBMODULE_ENTRIES = [
    Sbom::Submodules::Entry.new( path: 'vendor/c_exception', commit: '923835236bd2', status: ' ' ),
    Sbom::Submodules::Entry.new( path: 'vendor/cmock', commit: 'f2a70b41bb06', status: ' ' ),
    Sbom::Submodules::Entry.new( path: 'vendor/cmock/vendor/c_exception', commit: '923835236bd2', status: ' ' ),
    Sbom::Submodules::Entry.new( path: 'vendor/cmock/vendor/unity', commit: '2b67b99a4a87', status: ' ' ),
    Sbom::Submodules::Entry.new( path: 'vendor/unity', commit: '2b80d1a35727', status: ' ' )
  ].freeze

  def build(**overrides)
    defaults = {
      ceedling_version: '1.2.0',
      declared: { 'rake' => '>= 12, < 14', 'thor' => '~> 1.3' },
      closure: { 'rake' => '13.2.1', 'thor' => '1.5.0', 'unicode-emoji' => '4.2.0' },
      submodules: SUBMODULE_ENTRIES,
      header_versions: { unity: '2.7.2', cmock: '2.7.2', cexception: '1.3.5' },
      diy_version: '1.1.2',
      licenses: { '.' => 'MIT', 'vendor/unity' => 'MIT' },
      excluded_gems: ['rspec', 'rubocop']
    }

    described_class.new( **defaults.merge( overrides ) ).document
  end

  describe 'the root component' do
    it 'is Ceedling itself, at the version being released' do
      root = build.root
      expect( root.name ).to eq('ceedling')
      expect( root.purl ).to eq('pkg:gem/ceedling@1.2.0')
    end
  end

  describe 'runtime gem components' do
    it 'carries the resolved version in the identifier' do
      rake = build.all_components.find { |c| c.name == 'rake' }
      expect( rake.purl ).to eq('pkg:gem/rake@13.2.1')
    end

    it 'keeps the declared constraint beside the resolved version' do
      rake = build.all_components.find { |c| c.name == 'rake' }
      expect( rake.declared ).to eq('>= 12, < 14')
    end

    it 'leaves a transitive dependency without a declared constraint, having none' do
      emoji = build.all_components.find { |c| c.name == 'unicode-emoji' }
      expect( emoji.declared ).to be_nil
      expect( emoji.purl ).to eq('pkg:gem/unicode-emoji@4.2.0')
    end
  end

  describe 'vendored C components' do
    it 'identifies each by its pinned commit' do
      unity = build.all_components.find { |c| c.path == 'vendor/unity' }
      expect( unity.purl ).to eq('pkg:github/throwtheswitch/unity@2b80d1a35727')
    end

    it 'distinguishes the two Unity trees, which sit at different commits' do
      unity = build.all_components.select { |c| c.name == 'unity' }

      expect( unity.map( &:purl ).uniq.size ).to eq(2)
      expect( unity.map( &:path ) ).to contain_exactly( 'vendor/unity', 'vendor/cmock/vendor/unity' )
    end

    it 'gives both CException trees the same identifier, their commits genuinely matching' do
      cexception = build.all_components.select { |c| c.name == 'cexception' }

      expect( cexception.map( &:purl ).uniq ).to eq(['pkg:github/throwtheswitch/cexception@923835236bd2'])
      expect( cexception.map( &:ref ).uniq.size ).to eq(2)
    end

    it 'names the CException repository, which differs from its directory' do
      # Directory is vendor/c_exception; the GitHub repository is CException
      cexception = build.all_components.find { |c| c.path == 'vendor/c_exception' }
      expect( cexception.purl ).to include('throwtheswitch/cexception')
    end

    it 'records the header version alongside the commit' do
      unity = build.all_components.find { |c| c.path == 'vendor/unity' }
      expect( unity.version ).to eq('2.7.2')
    end

    it 'attaches a license where one was found' do
      unity = build.all_components.find { |c| c.path == 'vendor/unity' }
      expect( unity.license ).to eq('MIT')
    end
  end

  describe 'the vendored DIY copy' do
    it 'appears once, as source shipped inside the gem rather than a fetched gem' do
      diy = build.all_components.select { |c| c.name == 'diy' }

      expect( diy.size ).to eq(1)
      expect( diy.first.path ).to eq('vendor/diy')
      expect( diy.first.purl ).to eq('pkg:gem/diy@1.1.2')
    end
  end

  describe 'the fff plugin' do
    it 'records the upstream it descends from, and that it has diverged' do
      fff = build.all_components.find { |c| c.path == 'plugins/fff' }

      expect( fff.pedigree.ancestors )
        .to eq(['pkg:github/electronvector/fake_function_framework@d3914ef0'])
      expect( fff.pedigree.notes ).to match(/modified/i)
    end

    it 'nests the framework itself, which carries no version marker' do
      fff = build.all_components.find { |c| c.path == 'plugins/fff' }
      inner = fff.children.first

      expect( inner.path ).to eq('plugins/fff/vendor/fff')
      expect( inner.purl ).to eq('pkg:github/meekrosoft/fff')
      expect( inner.version ).to be_nil
    end

    it 'is reached by flattening, so both formats emit it' do
      paths = build.all_components.map( &:path )
      expect( paths ).to include('plugins/fff', 'plugins/fff/vendor/fff')
    end

    it 'carries no identifier of its own, having been modified away from upstream' do
      # Pointing a PURL at the package it descends from would invite a scanner to
      # match advisories against code that differs. Pedigree says it instead.
      fff = build.all_components.find { |c| c.path == 'plugins/fff' }

      expect( fff.purl ).to be_nil
      expect( fff.notes ).to match(/pedigree/i)
    end
  end

  describe 'document properties' do
    it 'states the scope boundary, so an SBOM found alone still carries it' do
      expect( build.properties.values.join( ' ' ) ).to match(/not.*user|as distributed/i)
    end

    it 'records that development dependencies are excluded, and which' do
      text = build.properties.values.join( ' ' )
      expect( text ).to match(/rspec/)
    end

    it 'names the plugin tool variability a project-level document cannot capture' do
      expect( build.properties.values.join( ' ' ) ).to match(/plugin/i)
    end
  end

  describe 'refusing to describe an incomplete checkout' do
    it 'raises when a submodule is not initialized, rather than omitting its version' do
      absent = [Sbom::Submodules::Entry.new( path: 'vendor/unity', commit: '2b80d1a3', status: '-' )]

      expect { build( submodules: absent ) }.to raise_error(Sbom::Inventory::Error, /vendor\/unity/)
    end
  end

end
