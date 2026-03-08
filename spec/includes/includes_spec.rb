# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/includes'

describe "Includes serialization" do
  it "produces valid hash structure" do
    original = [
      UserInclude.new("header.h"),
      SystemInclude.new("stdio.h"),
      MockInclude.new("mock_module.h")
    ]
    
    hashes = Includes.to_hashes(original)
    
    expect(hashes.length).to eq(3)
    
    expect(hashes[0]).to have_key('type')
    expect(hashes[0]).to have_key('filepath')
    expect(hashes[0]['type']).to eq('user')
    expect(hashes[0]['filepath']).to eq('header.h')
    
    expect(hashes[1]['type']).to eq('system')
    expect(hashes[1]['filepath']).to eq('stdio.h')
    
    expect(hashes[2]['type']).to eq('mock')
    expect(hashes[2]['filepath']).to eq('mock_module.h')
  end

  describe "round-trip serialization" do
    it "serializes and deserializes a single UserInclude" do
      original = [UserInclude.new("header.h")]
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(restored.length).to eq(1)
      expect(restored[0]).to eq(original[0])
      expect(restored[0].filename).to eq(original[0].filename)
      expect(restored[0].filepath).to eq(original[0].filepath)
      expect("#{restored[0]}").to eq("#{original[0]}")
    end

    it "serializes and deserializes a single SystemInclude" do
      original = [SystemInclude.new("stdio.h")]
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(restored.length).to eq(1)
      expect(restored[0]).to eq(original[0])
      expect(restored[0].filename).to eq(original[0].filename)
      expect(restored[0].filepath).to eq(original[0].filepath)
      expect("#{restored[0]}").to eq("#{original[0]}")
    end

    it "serializes and deserializes a single MockInclude" do
      original = [MockInclude.new("mock_module.h")]
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(restored.length).to eq(1)
      expect(restored[0]).to eq(original[0])
      expect(restored[0].filename).to eq(original[0].filename)
      expect(restored[0].filepath).to eq(original[0].filepath)
      expect("#{restored[0]}").to eq("#{original[0]}")
    end

    it "serializes and deserializes mixed include types" do
      original = [
        SystemInclude.new("stdio.h"),
        UserInclude.new("header.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h"),
        UserInclude.new("config.h")
      ]
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(restored.length).to eq(5)
      
      # Verify each include matches original
      original.each_with_index do |orig, idx|
        expect(restored[idx]).to eq(orig)
        expect(restored[idx].class).to eq(orig.class)
        expect(restored[idx].filename).to eq(orig.filename)
        expect(restored[idx].filepath).to eq(orig.filepath)
        expect("#{restored[idx]}").to eq("#{orig}")
      end
    end

    it "preserves order during serialization round-trip" do
      original = [
        UserInclude.new("first.h"),
        SystemInclude.new("second.h"),
        MockInclude.new("third.h"),
        UserInclude.new("fourth.h")
      ]
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(restored.map(&:filename)).to eq(["first.h", "second.h", "third.h", "fourth.h"])
    end

    it "handles includes with paths during serialization" do
      original = [
        UserInclude.new("path/to/header.h", use_path: true),
        SystemInclude.new("sys/stdio.h", use_path: true),
        MockInclude.new("mocks/mock_module.h", use_path: true)
      ]
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(restored.length).to eq(3)
      expect(restored[0].filepath).to eq("path/to/header.h")
      expect(restored[1].filepath).to eq("sys/stdio.h")
      expect(restored[2].filepath).to eq("mocks/mock_module.h")
    end

    it "handles empty array" do
      original = []
      
      hashes = Includes.to_hashes(original)
      restored = Includes.from_hashes(hashes)
      
      expect(hashes).to eq([])
      expect(restored).to eq([])
    end
  end

  describe "error handling" do
    it "raises error for invalid include type in to_hashes" do
      invalid_include = Object.new
      
      expect {
        Includes.to_hashes([invalid_include])
      }.to raise_error(ArgumentError, /Unknown Include type/)
    end

    it "raises error for hash missing type key in from_hashes" do
      invalid_hash = [{ 'filepath' => 'header.h' }]
      
      expect {
        Includes.from_hashes(invalid_hash)
      }.to raise_error(ArgumentError, /Hash missing 'type' key/)
    end

    it "raises error for hash missing filepath key in from_hashes" do
      invalid_hash = [{ 'type' => 'user' }]
      
      expect {
        Includes.from_hashes(invalid_hash)
      }.to raise_error(ArgumentError, /Hash missing 'filepath' key/)
    end

    it "raises error for invalid type value in from_hashes" do
      invalid_hash = [{ 'type' => 'invalid', 'filepath' => 'header.h' }]
      
      expect {
        Includes.from_hashes(invalid_hash)
      }.to raise_error(ArgumentError, /Invalid include type: invalid/)
    end
  end
end

describe "Includes filtering" do
  describe "system()" do
    it "extracts only SystemInclude objects from mixed list" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h"),
        UserInclude.new("config.h")
      ]
      
      system_includes = Includes.system(includes)
      
      expect(system_includes.length).to eq(2)
      expect(system_includes[0]).to be_a(SystemInclude)
      expect(system_includes[0].filename).to eq("stdio.h")
      expect(system_includes[1]).to be_a(SystemInclude)
      expect(system_includes[1].filename).to eq("stdlib.h")
    end

    it "returns empty array when no SystemInclude objects present" do
      includes = [
        UserInclude.new("header.h"),
        MockInclude.new("mock_module.h"),
        UserInclude.new("config.h")
      ]
      
      system_includes = Includes.system(includes)
      
      expect(system_includes).to eq([])
    end

    it "returns all includes when all are SystemInclude objects" do
      includes = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("string.h")
      ]
      
      system_includes = Includes.system(includes)
      
      expect(system_includes.length).to eq(3)
      expect(system_includes).to eq(includes)
    end

    it "handles empty array" do
      includes = []
      
      system_includes = Includes.system(includes)
      
      expect(system_includes).to eq([])
    end

    it "preserves order of SystemInclude objects" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("first.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("second.h"),
        SystemInclude.new("third.h")
      ]
      
      system_includes = Includes.system(includes)
      
      expect(system_includes.map(&:filename)).to eq(["first.h", "second.h", "third.h"])
    end
  end

  describe "user()" do
    it "extracts only UserInclude objects from mixed list" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h"),
        UserInclude.new("config.h")
      ]
      
      user_includes = Includes.user(includes)
      
      expect(user_includes.length).to eq(3)
      expect(user_includes[0]).to be_a(UserInclude)
      expect(user_includes[0].filename).to eq("header.h")
      expect(user_includes[1]).to be_a(MockInclude)
      expect(user_includes[1].filename).to eq("mock_module.h")
      expect(user_includes[2]).to be_a(UserInclude)
      expect(user_includes[2].filename).to eq("config.h")
    end

    it "includes MockInclude objects as they are subclass of UserInclude" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        UserInclude.new("config.h")
      ]
      
      user_includes = Includes.user(includes)
      
      expect(user_includes.length).to eq(3)
      expect(user_includes[0]).to be_a(UserInclude)
      expect(user_includes[0].filename).to eq("header.h")
      expect(user_includes[1]).to be_a(MockInclude)
      expect(user_includes[1].filename).to eq("mock_module.h")
      expect(user_includes[2]).to be_a(UserInclude)
      expect(user_includes[2].filename).to eq("config.h")
    end

    it "returns empty array when no UserInclude objects present" do
      includes = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h")
      ]
      
      user_includes = Includes.user(includes)
      
      expect(user_includes).to eq([])
    end

    it "returns all includes when all are UserInclude or MockInclude objects" do
      includes = [
        UserInclude.new("header.h"),
        MockInclude.new("mock_module.h"),
        UserInclude.new("config.h")
      ]
      
      user_includes = Includes.user(includes)
      
      expect(user_includes.length).to eq(3)
      expect(user_includes).to eq(includes)
    end

    it "handles empty array" do
      includes = []
      
      user_includes = Includes.user(includes)
      
      expect(user_includes).to eq([])
    end

    it "preserves order of UserInclude and MockInclude objects" do
      includes = [
        SystemInclude.new("stdio.h"),
        UserInclude.new("first.h"),
        MockInclude.new("second.h"),
        SystemInclude.new("stdlib.h"),
        UserInclude.new("third.h")
      ]
      
      user_includes = Includes.user(includes)
      
      expect(user_includes.map(&:filename)).to eq(["first.h", "second.h", "third.h"])
    end
  end

  describe "system() and user() together" do
    it "partition includes into system and user groups" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h"),
        UserInclude.new("config.h")
      ]
      
      system_includes = Includes.system(includes)
      user_includes = Includes.user(includes)
      
      expect(system_includes.length).to eq(2)
      expect(user_includes.length).to eq(3)
      expect(system_includes.length + user_includes.length).to eq(includes.length)
    end

    it "ensures no overlap between system and user results" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h")
      ]
      
      system_includes = Includes.system(includes)
      user_includes = Includes.user(includes)
      
      system_filenames = system_includes.map(&:filename)
      user_filenames = user_includes.map(&:filename)
      
      expect(system_filenames & user_filenames).to eq([])
    end
  end
end

describe "Includes sorting" do
  describe "sort!()" do
    it "moves SystemInclude objects to the beginning" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h"),
        UserInclude.new("config.h")
      ]
      
      result = Includes.sort!(includes)
      
      expect(result.length).to eq(5)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1]).to be_a(SystemInclude)
      expect(result[1].filename).to eq("stdlib.h")
      expect(result[2]).to be_a(UserInclude)
      expect(result[3]).to be_a(MockInclude)
      expect(result[4]).to be_a(UserInclude)
    end

    it "mutates the original array" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("config.h")
      ]
      
      original_object_id = includes.object_id
      result = Includes.sort!(includes)
      
      expect(result.object_id).to eq(original_object_id)
      expect(includes[0]).to be_a(SystemInclude)
      expect(includes[1]).to be_a(UserInclude)
      expect(includes[2]).to be_a(UserInclude)
    end

    it "handles array with only SystemInclude objects" do
      includes = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("string.h")
      ]
      
      original_order = includes.map(&:filename)
      Includes.sort!(includes)
      
      expect(includes.map(&:filename)).to eq(original_order)
    end

    it "handles array with only UserInclude objects" do
      includes = [
        UserInclude.new("header.h"),
        MockInclude.new("mock_module.h"),
        UserInclude.new("config.h")
      ]
      
      original_order = includes.map(&:filename)
      Includes.sort!(includes)
      
      expect(includes.map(&:filename)).to eq(original_order)
    end

    it "handles empty array" do
      includes = []
      
      result = Includes.sort!(includes)
      
      expect(result).to eq([])
      expect(includes).to eq([])
    end

    it "handles single element array" do
      includes = [UserInclude.new("header.h")]
      
      Includes.sort!(includes)
      
      expect(includes.length).to eq(1)
      expect(includes[0].filename).to eq("header.h")
    end

    it "returns the modified array" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h")
      ]
      
      result = Includes.sort!(includes)
      
      expect(result).to be(includes)
      expect(result[0]).to be_a(SystemInclude)
    end

    it "treats MockInclude as UserInclude for sorting" do
      includes = [
        MockInclude.new("mock_first.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("header.h"),
        MockInclude.new("mock_second.h")
      ]
      
      Includes.sort!(includes)
      
      expect(includes[0]).to be_a(SystemInclude)
      expect(includes[1]).to be_a(MockInclude)
      expect(includes[1].filename).to eq("mock_first.h")
      expect(includes[2]).to be_a(UserInclude)
      expect(includes[3]).to be_a(MockInclude)
      expect(includes[3].filename).to eq("mock_second.h")
    end
  end

  describe "sort()" do
    it "returns a new sorted array without mutating original" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("config.h")
      ]
      
      original_order = includes.map(&:filename)
      result = Includes.sort(includes)
      
      expect(result.object_id).not_to eq(includes.object_id)
      expect(includes.map(&:filename)).to eq(original_order)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[1]).to be_a(UserInclude)
      expect(result[2]).to be_a(UserInclude)
    end

    it "produces same result as sort! but without mutation" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h")
      ]
      
      includes_for_sort = includes.clone
      includes_for_sort_bang = includes.clone
      
      sorted = Includes.sort(includes_for_sort)
      sorted_bang = Includes.sort!(includes_for_sort_bang)
      
      expect(sorted.map(&:filename)).to eq(sorted_bang.map(&:filename))
      expect(sorted.map(&:class)).to eq(sorted_bang.map(&:class))
    end

    it "handles empty array" do
      includes = []
      
      result = Includes.sort(includes)
      
      expect(result).to eq([])
      expect(result.object_id).not_to eq(includes.object_id)
    end
  end
end
