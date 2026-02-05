
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partializer'

describe Partializer do
  before(:each) do
    @partializer_helper = double( "PartializerHelper" )
    @file_path_utils = double( "FilePathUtils" )
    @file_finder = double( "FileFinder" )

    @partializer = described_class.new(
      {
        :partializer_helper => @partializer_helper,
        :file_path_utils => @file_path_utils,
        :file_finder => @file_finder
      }
    )
  end

  context "#sanitize_includes" do
    it "returns empty array when input is empty" do
      includes = []
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([])
    end

    it "removes the module's own header from includes list" do
      includes = ['header1.h', 'module.h', 'module.H', 'header2.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header1.h', 'header2.h'])
      expect(result).not_to include('module.h')
      expect(result).not_to include('module.H')
    end

    it "returns empty array when only module header is present" do
      includes = ['module.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq([])
    end

    it "removes duplicate includes" do
      includes = ['header1.h', 'header2.h', 'header1.h', 'header3.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header1.h', 'header2.h', 'header3.h'])
    end

    it "removes duplicate module includes" do
      includes = ['header1.h', 'module.h', 'header2.h', 'module.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header1.h', 'header2.h'])
    end

    it "preserves order when removing duplicates" do
      includes = ['header3.h', 'header1.h', 'header2.h', 'header1.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      expect(result).to eq(['header3.h', 'header1.h', 'header2.h'])
    end

    it "distinguishes includes with different extensions" do
      includes = ['header1.h', 'header1.H', 'header1.hh']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      # Should only remove includes with extact filename match
      expect(result.length).to eq(3)
    end

    it "is not fooled by uncommon file naming conventions" do
      includes = ['header1.12.h', 'header1.13.h', 'header1.14.h']
      result = @partializer.sanitize_includes(name: 'module', includes: includes)
      
      # Should only remove includes with extact filename match
      expect(result.length).to eq(3)
    end
  end

end