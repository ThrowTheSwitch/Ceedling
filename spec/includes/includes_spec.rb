# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
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
      expect(result[1]).to be_a(SystemInclude)
      expect(result[2]).not_to be_a(SystemInclude)
      expect(result[3]).not_to be_a(SystemInclude)
      expect(result[4]).not_to be_a(SystemInclude)
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
      expect(includes[1]).not_to be_a(SystemInclude)
      expect(includes[2]).not_to be_a(SystemInclude)
    end

    it "handles array with only SystemInclude objects" do
      includes = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("string.h")
      ]
      
      Includes.sort!(includes)
      
      expect(result.length).to eq(3)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[1]).to be_a(SystemInclude)
      expect(result[2]).to be_a(SystemInclude)
    end

    it "handles array with only UserInclude objects" do
      includes = [
        UserInclude.new("header.h"),
        MockInclude.new("mock_module.h"),
        UserInclude.new("config.h")
      ]
      
      Includes.sort!(includes)
      
      expect(result.length).to eq(3)
      expect(result[0]).to be_a(UserInclude)
      expect(result[1]).to be_a(UserInclude)
      expect(result[2]).to be_a(UserInclude)
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

    it "treats UserInclude derivative as UserInclude for sorting" do
      includes = [
        MockInclude.new("mock_first.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("header.h"),
        MockInclude.new("mock_second.h")
      ]
      
      Includes.sort!(includes)
      
      expect(includes[0]).to be_a(SystemInclude)
      expect(includes[1]).to be_a(UserInclude)
      expect(includes[2]).to be_a(UserInclude)
      expect(includes[3]).to be_a(UserInclude)
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

    it "handles empty array" do
      includes = []
      
      result = Includes.sort(includes)
      
      expect(result).to eq([])
      expect(result.object_id).not_to eq(includes.object_id)
    end
  end
end

describe "Includes sanitization" do
  describe "sanitize!()" do
    it "removes duplicate includes" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h")
      ]
      
      result = Includes.sanitize!(includes)
      
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1]).to be_a(UserInclude)
      expect(result[1].filename).to eq("header.h")
    end

    it "mutates the original array" do
      includes = [
        UserInclude.new("header.h"),
        UserInclude.new("header.h")
      ]
      
      original_object_id = includes.object_id
      result = Includes.sanitize!(includes)
      
      expect(result.object_id).to eq(original_object_id)
      expect(includes.length).to eq(1)
    end

    # `sort()` test cases thoroughly cover this handling
    it "moves system includes to the beginning" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_module.h"),
        SystemInclude.new("stdlib.h")
      ]
      
      Includes.sanitize!(includes)
      
      expect(includes[0]).to be_a(SystemInclude)
      expect(includes[1]).to be_a(SystemInclude)
      expect(includes[2]).to be_a(UserInclude)
      expect(includes[3]).to be_a(UserInclude)
    end

    it "handles empty array" do
      includes = []
      
      result = Includes.sanitize!(includes)
      
      expect(result).to eq([])
    end

    it "handles array with single element" do
      includes = [UserInclude.new("header.h")]
      
      result = Includes.sanitize!(includes)
      
      expect(result.length).to eq(1)
      expect(result[0].filename).to eq("header.h")
    end

    it "preserves MockInclude as UserInclude subclass" do
      includes = [
        MockInclude.new("mock_first.h"),
        SystemInclude.new("stdio.h"),
        MockInclude.new("mock_first.h")
      ]
      
      Includes.sanitize!(includes)
      
      expect(includes.length).to eq(2)
      expect(includes[0]).to be_a(SystemInclude)
      expect(includes[1]).to be_a(MockInclude)
    end

    it "applies custom rejection block" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("config.h"),
        SystemInclude.new("stdlib.h")
      ]
      
      # Reject all includes with 'std' in the filename
      result = Includes.sanitize!(includes) do |include, all|
        include.filename.include?('std')
      end
      
      expect(result.length).to eq(2)
      expect(includes[0]).to be_a(UserInclude)
      expect(includes[1]).to be_a(UserInclude)
    end

    it "handles duplicates and custom rejection together" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("header.h"),
        UserInclude.new("test.h"),
        SystemInclude.new("stdio.h")
      ]
      
      result = Includes.sanitize!(includes) do |include, all|
        include.filename.include?('test')
      end
      
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1]).to be_a(UserInclude)
      expect(result[1].filename).to eq("header.h")
    end

    it "returns the modified array" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h")
      ]
      
      result = Includes.sanitize!(includes)
      
      expect(result).to be(includes)
    end

    it "handles all duplicates scenario" do
      includes = [
        UserInclude.new("header.h"),
        UserInclude.new("header.h"),
        UserInclude.new("header.h")
      ]
      
      result = Includes.sanitize!(includes)
      
      expect(result.length).to eq(1)
      expect(result[0].filename).to eq("header.h")
    end

    it "handles custom rejection that removes all includes" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h")
      ]
      
      result = Includes.sanitize!(includes) { |include, all| true }
      
      expect(result).to eq([])
    end

    it "handles custom rejection that removes no includes" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("config.h")
      ]
      
      result = Includes.sanitize!(includes) { |include, all| false }
      
      expect(result.length).to eq(3)
      expect(result[0]).to be_a(SystemInclude)
    end
  end

  # Simple validation of sanitize() as a variant of sanitize!()
  describe "sanitize()" do
    it "returns a new array without mutating original" do
      includes = [
        UserInclude.new("header.h"),
        SystemInclude.new("stdio.h"),
        UserInclude.new("header.h")
      ]
      
      original_order = includes.map(&:filename)
      original_length = includes.length
      result = Includes.sanitize(includes)
      
      expect(result.object_id).not_to eq(includes.object_id)
      expect(includes.length).to eq(original_length)
      expect(includes.map(&:filename)).to eq(original_order)
      expect(result.length).to eq(2)
    end
  end
end

describe "Includes reconciliation" do
  describe "reconcile()" do
    it "returns intersection of bare and system includes" do
      bare = [
        Include.new("header.h"),
        Include.new("stdio.h"),
        Include.new("stdlib.h")
      ]
      
      user = []
      
      system = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("string.h")
      ]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1]).to be_a(SystemInclude)
      expect(result[1].filename).to eq("stdlib.h")
    end

    it "returns intersection of bare and user includes" do
      bare = [
        Include.new("header.h"),
        Include.new("config.h"),
        Include.new("stdio.h")
      ]
      
      user = [
        UserInclude.new("header.h"),
        UserInclude.new("config.h"),
        UserInclude.new("extra.h")
      ]
      
      system = []
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(UserInclude)
      expect(result[0].filename).to eq("header.h")
      expect(result[1]).to be_a(UserInclude)
      expect(result[1].filename).to eq("config.h")
    end

    it "returns combined intersection of bare with both user and system includes" do
      bare = [
        Include.new("header.h"),
        Include.new("stdio.h"),
        Include.new("config.h"),
        Include.new("stdlib.h")
      ]
      
      user = [
        UserInclude.new("header.h"),
        UserInclude.new("config.h"),
        UserInclude.new("extra.h")
      ]
      
      system = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("string.h")
      ]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(4)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1]).to be_a(SystemInclude)
      expect(result[1].filename).to eq("stdlib.h")
      expect(result[2]).to be_a(UserInclude)
      expect(result[2].filename).to eq("header.h")
      expect(result[3]).to be_a(UserInclude)
      expect(result[3].filename).to eq("config.h")
    end

    it "places system includes before user includes" do
      bare = [
        Include.new("header.h"),
        Include.new("stdio.h")
      ]
      
      user = [UserInclude.new("header.h")]
      system = [SystemInclude.new("stdio.h")]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result[0]).to be_a(SystemInclude)
      expect(result[1]).to be_a(UserInclude)
    end

    it "handles MockInclude as UserInclude subclass" do
      bare = [
        Include.new("mock_module.h"),
        Include.new("stdio.h")
      ]
      
      user = [
        MockInclude.new("mock_module.h"),
        UserInclude.new("header.h")
      ]
      
      system = [SystemInclude.new("stdio.h")]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(2)
      expect(result[0]).to be_a(SystemInclude)
      expect(result[1]).to be_a(MockInclude)
      expect(result[1].filename).to eq("mock_module.h")
    end

    it "returns empty array when bare is empty" do
      bare = []
      user = [UserInclude.new("header.h")]
      system = [SystemInclude.new("stdio.h")]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result).to eq([])
    end

    it "returns empty array when no intersections exist" do
      bare = [
        Include.new("header.h"),
        Include.new("stdio.h")
      ]
      
      user = [UserInclude.new("config.h")]
      system = [SystemInclude.new("stdlib.h")]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result).to eq([])
    end

    it "handles empty user includes" do
      bare = [
        Include.new("stdio.h"),
        Include.new("stdlib.h")
      ]
      
      user = []
      
      system = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h")
      ]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(2)
      expect(result.all? { |inc| inc.is_a?(SystemInclude) }).to be true
    end

    it "handles empty system includes" do
      bare = [
        Include.new("header.h"),
        Include.new("config.h")
      ]
      
      user = [
        UserInclude.new("header.h"),
        UserInclude.new("config.h")
      ]
      
      system = []
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(2)
      expect(result.all? { |inc| inc.is_a?(UserInclude) }).to be true
    end

    it "handles all empty arrays" do
      result = Includes.reconcile(bare: [], user: [], system: [])
      
      expect(result).to eq([])
    end

    it "filters out user includes not in bare list" do
      bare = [
        Include.new("header.h")
      ]
      
      user = [
        UserInclude.new("header.h"),
        UserInclude.new("config.h"),
        UserInclude.new("extra.h")
      ]
      
      system = []
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(1)
      expect(result[0].filename).to eq("header.h")
    end

    it "filters out system includes not in bare list" do
      bare = [
        Include.new("stdio.h")
      ]
      
      user = []
      
      system = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("string.h")
      ]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(1)
      expect(result[0].filename).to eq("stdio.h")
    end

    it "handles duplicate filenames in bare list" do
      bare = [
        Include.new("header.h"),
        Include.new("header.h"),
        Include.new("stdio.h")
      ]
      
      user = [UserInclude.new("header.h")]
      system = [SystemInclude.new("stdio.h")]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      # Should still only return one of each
      expect(result.length).to eq(2)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1].filename).to eq("header.h")
    end

    it "raises ArgumentError when bare is not an array" do
      expect {
        Includes.reconcile(bare: "not an array", user: [], system: [])
      }.to raise_error(ArgumentError, "`bare` must be an Array of Include objects")
    end

    it "raises ArgumentError when bare contains non-Include objects" do
      expect {
        Includes.reconcile(bare: ["string"], user: [], system: [])
      }.to raise_error(ArgumentError, "`bare` must be an Array of Include objects")
    end

    it "raises ArgumentError when user is not an array" do
      expect {
        Includes.reconcile(bare: [], user: "not an array", system: [])
      }.to raise_error(ArgumentError, "`user` must be an Array of UserInclude objects")
    end

    it "raises ArgumentError when user contains non-UserInclude objects" do
      expect {
        Includes.reconcile(bare: [], user: [SystemInclude.new("stdio.h")], system: [])
      }.to raise_error(ArgumentError, "`user` must be an Array of UserInclude objects")
    end

    it "raises ArgumentError when system is not an array" do
      expect {
        Includes.reconcile(bare: [], user: [], system: "not an array")
      }.to raise_error(ArgumentError, "`system` must be an Array of SystemInclude objects")
    end

    it "raises ArgumentError when system contains non-SystemInclude objects" do
      expect {
        Includes.reconcile(bare: [], user: [], system: [UserInclude.new("header.h")])
      }.to raise_error(ArgumentError, "`system` must be an Array of SystemInclude objects")
    end

    it "accepts MockInclude objects in user array" do
      bare = [Include.new("mock_module.h")]
      user = [MockInclude.new("mock_module.h")]
      system = []
      
      expect {
        result = Includes.reconcile(bare: bare, user: user, system: system)
        expect(result.length).to eq(1)
        expect(result[0]).to be_a(MockInclude)
      }.not_to raise_error
    end

    it "handles complex mixed scenario with all include types" do
      bare = [
        Include.new("stdio.h"),
        Include.new("header.h"),
        Include.new("mock_module.h"),
        Include.new("stdlib.h"),
        Include.new("config.h"),
        Include.new("string.h"),
        Include.new("utils.h")
      ]
      
      user = [
        UserInclude.new("header.h"),
        MockInclude.new("mock_module.h"),
        UserInclude.new("config.h"),
        UserInclude.new("extra.h")
      ]
      
      system = [
        SystemInclude.new("stdio.h"),
        SystemInclude.new("stdlib.h"),
        SystemInclude.new("math.h")
      ]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(5)
      
      # Verify system includes come first
      expect(result[0]).to be_a(SystemInclude)
      expect(result[0].filename).to eq("stdio.h")
      expect(result[1]).to be_a(SystemInclude)
      expect(result[1].filename).to eq("stdlib.h")
      
      # Verify user includes come after
      expect(result[2]).to be_a(UserInclude)
      expect(result[2].filename).to eq("header.h")
      expect(result[3]).to be_a(MockInclude)
      expect(result[3].filename).to eq("mock_module.h")
      expect(result[4]).to be_a(UserInclude)
      expect(result[4].filename).to eq("config.h")
      
      # Verify excluded includes
      result_filenames = result.map(&:filename)
      expect(result_filenames).not_to include("string.h")
      expect(result_filenames).not_to include("utils.h")
      expect(result_filenames).not_to include("extra.h")
      expect(result_filenames).not_to include("math.h")
    end

    it "returns new array without mutating input arrays" do
      bare = [
        Include.new("header.h"),
        Include.new("stdio.h")
      ]
      
      user = [UserInclude.new("header.h")]
      system = [SystemInclude.new("stdio.h")]
      
      bare_original = bare.dup
      user_original = user.dup
      system_original = system.dup
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(bare).to eq(bare_original)
      expect(user).to eq(user_original)
      expect(system).to eq(system_original)
      expect(result.object_id).not_to eq(bare.object_id)
    end

    it "handles large lists efficiently" do
      bare = (1..100).map { |i| Include.new("header#{i}.h") } +
             (1..100).map { |i| Include.new("sys#{i}.h") }
      
      user = (1..50).map { |i| UserInclude.new("header#{i}.h") }
      system = (1..50).map { |i| SystemInclude.new("sys#{i}.h") }
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      expect(result.length).to eq(100)
      
      # Verify system includes come first
      system_count = result.take_while { |inc| inc.is_a?(SystemInclude) }.count
      expect(system_count).to eq(50)
      
      # Verify user includes come after
      user_count = result.drop(50).count { |inc| inc.is_a?(UserInclude) }
      expect(user_count).to eq(50)
    end

    it "handles includes with path separators in filenames" do
      bare = [
        Include.new("subdir/header.h"),
        Include.new("sys/types.h")
      ]
      
      user = [UserInclude.new("header.h")]
      system = [SystemInclude.new("types.h")]
      
      result = Includes.reconcile(bare: bare, user: user, system: system)
      
      # Should match by filename only
      expect(result.length).to eq(2)
      expect(result[0].filename).to eq("types.h")
      expect(result[1].filename).to eq("header.h")
    end
  end
end    
