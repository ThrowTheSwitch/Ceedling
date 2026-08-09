# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filename_extension'

describe FilenameExtension do

  describe '#initialize' do
    it 'wraps a single String in a one-element collection' do
      expect(FilenameExtension.new('.c').to_a).to eq(['.c'])
    end

    it 'leaves an Array of Strings as its own collection' do
      expect(FilenameExtension.new(['.s', '.S']).to_a).to eq(['.s', '.S'])
    end
  end

  describe '#primary' do
    it 'is the only entry when configured with a single String' do
      expect(FilenameExtension.new('.c').primary).to eq('.c')
    end

    it 'is the first entry when configured with a list' do
      expect(FilenameExtension.new(['.s', '.S']).primary).to eq('.s')
    end
  end

  describe '#match?' do
    it 'is true when the filepath ends with the single configured extension' do
      expect(FilenameExtension.new('.c').match?('foo.c')).to be true
    end

    it 'is false when the filepath ends with a different extension' do
      expect(FilenameExtension.new('.c').match?('foo.cpp')).to be false
    end

    it 'is true when the filepath ends with any entry of a configured list' do
      extension = FilenameExtension.new(['.s', '.S'])
      expect(extension.match?('foo.s')).to be true
      expect(extension.match?('foo.S')).to be true
    end

    it 'is false when the filepath ends with none of a configured list' do
      expect(FilenameExtension.new(['.s', '.S']).match?('foo.c')).to be false
    end
  end

  describe '#candidates' do
    it 'produces one candidate filename per configured extension' do
      extension = FilenameExtension.new(['.s', '.S'])
      expect(extension.candidates('foo')).to eq(['foo.s', 'foo.S'])
    end

    it 'replaces an existing extension on the basename rather than appending to it' do
      extension = FilenameExtension.new(['.o'])
      expect(extension.candidates('foo.c')).to eq(['foo.o'])
    end
  end

  describe '#glob_patterns' do
    it 'produces one wildcard fragment per configured extension' do
      extension = FilenameExtension.new(['.s', '.S'])
      expect(extension.glob_patterns('src')).to eq([File.join('src', '*.s'), File.join('src', '*.S')])
    end
  end

  describe '#to_s' do
    it 'renders a single extension plainly' do
      expect(FilenameExtension.new('.c').to_s).to eq('.c')
    end

    it 'joins multiple extensions with "or" for a human-readable message' do
      expect(FilenameExtension.new(['.s', '.S']).to_s).to eq('.s or .S')
    end
  end

  describe '#empty?' do
    it 'is true when configured with no extensions at all' do
      expect(FilenameExtension.new([]).empty?).to be true
    end

    it 'is false when configured with at least one extension' do
      expect(FilenameExtension.new('.c').empty?).to be false
    end
  end

  describe Enumerable do
    it 'supports include? via the underlying collection' do
      expect(FilenameExtension.new(['.s', '.S']).include?('.S')).to be true
      expect(FilenameExtension.new(['.s', '.S']).include?('.c')).to be false
    end

    it 'supports map via the underlying collection' do
      expect(FilenameExtension.new(['.s', '.S']).map(&:upcase)).to eq(['.S', '.S'])
    end
  end

end
