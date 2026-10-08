# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Unit coverage for QuoteIncludeIsolator through a doubled file layer.
#
# What a staged directory really holds, and what a compiler makes of a staged copy, are
# filesystem and toolchain facts proven at integration tier in
# spec/integration/quote_include_isolator_spec.rb. This spec owns the decisions the
# isolator makes about which file operations to request.

require 'spec_helper'
require 'ceedling/quote_include_isolator'
require 'ceedling/constants'

describe QuoteIncludeIsolator do
  before(:each) do
    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator')
    allow(@loginator).to receive(:log)
    allow(@file_wrapper).to receive(:mkdir_tmp).and_return('build/tmp1')
    allow(@file_wrapper).to receive(:cp)
    allow(@file_wrapper).to receive(:rm_rf)

    @isolator = described_class.new( { :file_wrapper => @file_wrapper, :loginator => @loginator } )
  end

  describe '#isolate' do
    it 'copies each file into one fresh directory inside parent, named by basename alone' do
      isolation = @isolator.isolate( parent: 'build', files: ['src/a.h', 'lib/b.h'] )

      expect(@file_wrapper).to have_received(:mkdir_tmp).with(nil, 'build')
      expect(@file_wrapper).to have_received(:cp).with('src/a.h', 'build/tmp1/a.h')
      expect(@file_wrapper).to have_received(:cp).with('lib/b.h', 'build/tmp1/b.h')
      expect(isolation.dir).to eq('build/tmp1')
      expect(isolation.copy_of('lib/b.h')).to eq('build/tmp1/b.h')
    end

    it 'logs each staged copy at DEBUG verbosity' do
      @isolator.isolate( parent: 'build', files: ['src/a.h'] )

      expect(@loginator).to have_received(:log).with(a_string_including('src/a.h'), Verbosity::DEBUG)
    end

    # A #line directive makes every report about the copy name the original instead.
    it 'opens a location-preserving copy with a #line directive naming its original' do
      allow(@file_wrapper).to receive(:read_binary).with('src/gpio.c').and_return("int x;\n".b)
      allow(@file_wrapper).to receive(:write)

      @isolator.isolate( parent: 'build', files: ['src/gpio.c'], preserve_location: true )

      expect(@file_wrapper).to have_received(:write).with('build/tmp1/gpio.c', "#line 1 \"src/gpio.c\"\nint x;\n".b, 'wb')
      expect(@file_wrapper).to_not have_received(:cp)
    end

    # The directive is a C string literal, so a Windows path's separators need escaping.
    it 'escapes backslashes and quotes in the #line path' do
      allow(@file_wrapper).to receive(:read_binary).and_return(''.b)
      allow(@file_wrapper).to receive(:write)

      @isolator.isolate( parent: 'build', files: ['C:\\proj\\src\\gpio.c'], preserve_location: true )

      expect(@file_wrapper).to have_received(:write).with(anything, "#line 1 \"C:\\\\proj\\\\src\\\\gpio.c\"\n".b, 'wb')
    end
  end

  describe '#within' do
    it 'yields the isolation, then releases its directory' do
      yielded = nil
      @isolator.within( parent: 'build', files: ['src/a.h'] ) { |isolation| yielded = isolation }

      expect(yielded.dir).to eq('build/tmp1')
      expect(@file_wrapper).to have_received(:rm_rf).with('build/tmp1')
    end

    it 'releases the directory even when the block raises' do
      expect {
        @isolator.within( parent: 'build', files: ['src/a.h'] ) { raise 'boom' }
      }.to raise_error('boom')

      expect(@file_wrapper).to have_received(:rm_rf).with('build/tmp1')
    end
  end

  describe '#release' do
    it 'removes the directory and logs the removal at DEBUG verbosity' do
      @isolator.release('build/tmp1')

      expect(@file_wrapper).to have_received(:rm_rf).with('build/tmp1')
      expect(@loginator).to have_received(:log).with(a_string_including('build/tmp1'), Verbosity::DEBUG)
    end
  end

  describe QuoteIncludeIsolator::Isolation do
    # gcc writes a space in a dependency path as `\ `, so both spellings must map back.
    it 'restores original paths in plain and make-escaped spellings' do
      isolation = QuoteIncludeIsolator::Isolation.new('/b/my build/tmp1', { 'src/my gpio.c' => '/b/my build/tmp1/my gpio.c' })
      text = "gpio.o: /b/my\\ build/tmp1/my\\ gpio.c src/gpio.h\n# /b/my build/tmp1/my gpio.c\n"

      expect(isolation.restore_paths(text)).to eq("gpio.o: src/my\\ gpio.c src/gpio.h\n# src/my gpio.c\n")
    end

    it 'keeps backslashes of a Windows original intact' do
      isolation = QuoteIncludeIsolator::Isolation.new('b/tmp1', { 'C:\\src\\gpio.c' => 'b/tmp1/gpio.c' })

      expect(isolation.restore_paths('gpio.o: b/tmp1/gpio.c')).to eq('gpio.o: C:\\src\\gpio.c')
    end

    it 'restores paths within binary content' do
      isolation = QuoteIncludeIsolator::Isolation.new('b/tmp1', { 'src/gpio.c' => 'b/tmp1/gpio.c' })

      expect(isolation.restore_paths("gpio.o: b/tmp1/gpio.c\r\n".b)).to eq("gpio.o: src/gpio.c\r\n".b)
    end
  end

  describe '#restore_dependencies' do
    let(:isolation) { QuoteIncludeIsolator::Isolation.new('b/tmp1', { 'src/gpio.c' => 'b/tmp1/gpio.c' }) }

    it 'rewrites a dependency file so it names the original' do
      allow(@file_wrapper).to receive(:exist_with_retry?).with('gpio.d').and_return(true)
      allow(@file_wrapper).to receive(:read_binary).with('gpio.d').and_return("gpio.o: b/tmp1/gpio.c\n".b)
      allow(@file_wrapper).to receive(:write)

      @isolator.restore_dependencies(isolation, 'gpio.d')

      expect(@file_wrapper).to have_received(:write).with('gpio.d', "gpio.o: src/gpio.c\n".b, 'wb')
    end

    it 'leaves a dependency file untouched when it never names the copy' do
      allow(@file_wrapper).to receive(:exist_with_retry?).and_return(true)
      allow(@file_wrapper).to receive(:read_binary).and_return("gpio.o: src/gpio.c\n".b)

      expect(@file_wrapper).to_not receive(:write)
      @isolator.restore_dependencies(isolation, 'gpio.d')
    end

    # A compiler run without -MMD writes no dependency file at all.
    it 'does nothing when the dependency file does not exist' do
      allow(@file_wrapper).to receive(:exist_with_retry?).and_return(false)

      expect(@file_wrapper).to_not receive(:read_binary)
      @isolator.restore_dependencies(isolation, 'gpio.d')
    end
  end

  describe '#includes_by_name?' do
    def with_content(content)
      allow(@file_wrapper).to receive(:exist?).with('src/gpio.c').and_return(true)
      allow(@file_wrapper).to receive(:read).with('src/gpio.c').and_return(content)
    end

    it 'matches a quoted include of the header by name' do
      with_content("#include \"board.h\"\n")
      expect(@isolator.includes_by_name?('src/gpio.c', 'board.h')).to be true
    end

    it 'matches a quoted include carrying a path ahead of the name' do
      with_content("#include \"drivers/board.h\"\n")
      expect(@isolator.includes_by_name?('src/gpio.c', 'board.h')).to be true
    end

    # Only a quoted include takes the same-directory shortcut.
    it 'ignores an angle-bracket include and a different header sharing a suffix' do
      with_content("#include <board.h>\n#include \"myboard.h\"\n")
      expect(@isolator.includes_by_name?('src/gpio.c', 'board.h')).to be false
    end

    it 'is false for a file that does not exist' do
      allow(@file_wrapper).to receive(:exist?).with('src/gone.c').and_return(false)
      expect(@isolator.includes_by_name?('src/gone.c', 'board.h')).to be false
    end
  end
end
