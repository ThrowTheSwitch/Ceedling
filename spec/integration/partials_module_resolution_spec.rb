# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for resolving a Partial module name to real header and
# source files.
#
# Partials resolve a module name through the same chain every other file lookup
# uses: FileFinder, then FilenameExtension to supply candidate extensions, then
# FileFinderHelper, then PathMatcher to match trailing path segments. Those
# collaborators are real here. Only the Configurator and the Loginator are
# doubled, the first to supply collections and extensions and the second to
# capture the ambiguity NOTICE.
#
# The project shape under test is the one issue #1311 reports: two modules
# sharing a basename in different directories.

require 'spec_helper'
require 'ceedling/file_finder'
require 'ceedling/file_finder_helper'
require 'ceedling/filename_extension'
require 'ceedling/path_matcher'
require 'ceedling/constants'

describe 'Partial module resolution (integration)' do

  RESOLUTION_HEADERS = [
    'include/drivers/spi/config.h',
    'include/drivers/uart/config.h',
    'include/shared/types.h'
  ].freeze

  RESOLUTION_SOURCES = [
    'src/drivers/spi/config.c',
    'src/drivers/uart/config.c'
  ].freeze

  before(:each) do
    @logged = []
    loginator = double('loginator')
    allow(loginator).to receive(:log) { |msg, *_rest| @logged << msg }

    @configurator = double('configurator')
    allow(@configurator).to receive(:extension_header).and_return( FilenameExtension.new('.h') )
    allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
    allow(@configurator).to receive(:collection_all_headers).and_return( RESOLUTION_HEADERS )
    allow(@configurator).to receive(:collection_all_source).and_return( RESOLUTION_SOURCES )

    @finder = FileFinder.new({
      :configurator      => @configurator,
      :file_finder_helper => FileFinderHelper.new({ :loginator => loginator }),
      :file_path_utils   => double('file_path_utils'),
      :file_wrapper      => double('file_wrapper'),
      :yaml_wrapper      => double('yaml_wrapper')
    })
  end

  def notices
    @logged.select { |msg| msg.include?('Multiple files matched') }
  end

  context 'a module name carrying a path' do
    it 'resolves the header under the named directory and passes over the same-named sibling' do
      expect( @finder.find_header_file('drivers/uart/config', :ignore) )
        .to eq('include/drivers/uart/config.h')

      expect( notices ).to be_empty
    end

    it 'resolves the source under the named directory' do
      expect( @finder.find_source_file('drivers/uart/config', :ignore) )
        .to eq('src/drivers/uart/config.c')

      expect( notices ).to be_empty
    end

    # Matching is by trailing segments, so only as much path as it takes to
    # distinguish the file is required.
    it 'accepts a partial path that is still unambiguous' do
      expect( @finder.find_header_file('uart/config', :ignore) )
        .to eq('include/drivers/uart/config.h')
    end

    it 'resolves nothing when the named directory matches no file' do
      expect( @finder.find_header_file('drivers/i2c/config', :ignore) ).to be_nil
    end
  end

  context 'a bare module name matching more than one file' do
    # The winner is the collection's own first entry. Nothing about the module
    # name distinguishes the two candidates, so the choice rests entirely on
    # collection order.
    it 'chooses the first candidate and names the one it passed over' do
      expect( @finder.find_header_file('config', :ignore) )
        .to eq('include/drivers/spi/config.h')

      expect( notices.length ).to eq(1)
      expect( notices.first ).to include('include/drivers/uart/config.h')
      expect( notices.first ).to include('Add more path')
    end

    it 'chooses by collection order rather than by any property of the file' do
      allow(@configurator).to receive(:collection_all_headers)
        .and_return( RESOLUTION_HEADERS.reverse )

      expect( @finder.find_header_file('config', :ignore) )
        .to eq('include/drivers/uart/config.h')
    end
  end

  context 'a bare module name matching exactly one file' do
    it 'resolves silently' do
      expect( @finder.find_header_file('types', :ignore) )
        .to eq('include/shared/types.h')

      expect( notices ).to be_empty
    end
  end
end
