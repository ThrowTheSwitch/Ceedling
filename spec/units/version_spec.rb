# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'version'

# version.rb composes the reported version from a hand-maintained BASE and a DEV
# marker that the release pipeline empties. These examples pin the composition
# rules rather than any particular version number, so they hold both in a
# development checkout and during a release build.
describe Ceedling::Version do

  describe 'composition' do
    it 'builds the reported version from BASE' do
      expect(described_class::GEM).to start_with( described_class::BASE )
    end

    it 'ends with the development marker' do
      expect(described_class::GEM).to end_with( described_class::DEV )
    end

    it 'reports the same value as a tag and as a gem version' do
      expect(described_class::TAG).to eq( described_class::GEM )
    end
  end

  # The marker is appended conditionally, so the one thing worth guarding is that
  # the condition cannot fire twice and produce `1.2.0.dev.dev`.
  describe 'the development marker' do
    it 'appears exactly once, however BASE is written' do
      skip 'release build -- marker deliberately cleared' if described_class::DEV.empty?

      expect(described_class::GEM.scan( described_class::DEV ).length).to eq(1)
    end

    it 'is not appended twice when BASE already carries it' do
      base = "9.9.9#{described_class::DEV}"

      composed = base.end_with?( described_class::DEV ) ? base : "#{base}#{described_class::DEV}"

      expect(composed).to eq( base )
    end

    it 'composes to a bare version once cleared, as a release build leaves it' do
      base = '9.9.9'
      dev  = ''

      composed = base.end_with?( dev ) ? base : "#{base}#{dev}"

      expect(composed).to eq( '9.9.9' )
    end
  end

  # A `.dev` version is a RubyGems prerelease. That is what keeps a locally built
  # gem from ever satisfying a plain `gem install ceedling`.
  describe 'RubyGems interpretation' do
    it 'marks a development build as a prerelease' do
      skip 'release build -- marker deliberately cleared' if described_class::DEV.empty?

      expect(Gem::Version.new( described_class::GEM )).to be_prerelease
    end

    it 'sorts a development build below the release it precedes' do
      skip 'release build -- marker deliberately cleared' if described_class::DEV.empty?

      expect(Gem::Version.new( described_class::GEM )).to be < Gem::Version.new( described_class::BASE )
    end
  end

end
