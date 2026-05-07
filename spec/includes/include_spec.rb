# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'spec_helper'
require 'ceedling/includes/includes'


describe UserInclude do
  describe "Essential uses" do
    it "creates a UserInclude with a simple header file" do
      include_obj = UserInclude.new("header.h")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include "header.h"')
      expect(include_obj).to eq('header.h')
    end

    it "creates a UserInclude with a path but does not provide path in string expansion" do
      include_obj = UserInclude.new("path/to/header.h")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("path/to/header.h")
      expect("#{include_obj}").to eq('#include "header.h"')
      expect(include_obj).to eq('header.h')
    end

    it "creates a UserInclude with a path and used path in string expansion" do
      include_obj = UserInclude.new("path/to/header.h", use_path: true)
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("path/to/header.h")
      expect("#{include_obj}").to eq('#include "path/to/header.h"')
      expect(include_obj).to eq('path/to/header.h')
    end
  end

  describe "Graceful handling of input" do
    it "creates a UserInclude removing #include directive syntax" do
      include_obj = UserInclude.new("#include \"header.h\"")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include "header.h"')
      expect(include_obj).to eq('header.h')
    end

    it "creates a UserInclude removing quotes and whitespace" do
      include_obj = UserInclude.new("\"header.h  \"")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include "header.h"')
      expect(include_obj).to eq('header.h')
    end

    it "creates a UserInclude from a system include" do
      include_obj = UserInclude.new("<header.h>")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include "header.h"')
      expect(include_obj).to eq('header.h')
    end
  end

  describe "edge cases" do
    it "raises an exception for empty string" do
      expect { UserInclude.new("  ") }.to raise_error(ArgumentError)
    end

    it "handles include with spaces" do
      include_obj = UserInclude.new("my header.h")
      
      expect("#{include_obj}").to eq('#include "my header.h"')
      expect(include_obj).to eq('my header.h')
    end

    it "handles include with special characters" do
      include_obj = UserInclude.new("header-v1.2.h")
      
      expect("#{include_obj}").to eq('#include "header-v1.2.h"')
      expect(include_obj).to eq('header-v1.2.h')
    end
  end
end

describe SystemInclude do
  describe "Essential uses" do
    it "creates a SystemInclude with a simple header file" do
      include_obj = SystemInclude.new("header.h")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include <header.h>')
      expect(include_obj).to eq('header.h')
    end

    it "creates a SystemInclude with a path but does not provide path in string expansion" do
      include_obj = SystemInclude.new("path/to/header.h")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("path/to/header.h")
      expect("#{include_obj}").to eq('#include <header.h>')
      expect(include_obj).to eq('header.h')
    end

    it "creates a SystemInclude with a path and used path in string expansion" do
      include_obj = SystemInclude.new("path/to/header.h", use_path: true)
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("path/to/header.h")
      expect("#{include_obj}").to eq('#include <path/to/header.h>')
      expect(include_obj).to eq('path/to/header.h')
    end
  end

  describe "Graceful handling of input" do
    it "creates a SystemInclude from #include directive" do
      include_obj = SystemInclude.new("#include <header.h>")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include <header.h>')
      expect(include_obj).to eq('header.h')
    end

    it "creates a SystemInclude removing quotes and whitespace" do
      include_obj = SystemInclude.new("\"header.h  \"")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include <header.h>')
      expect(include_obj).to eq('header.h')
    end

    it "creates a SystemInclude from a user include" do
      include_obj = SystemInclude.new("\"<header.h\"")
      
      expect(include_obj.filename).to eq("header.h")
      expect(include_obj.filepath).to eq("header.h")
      expect("#{include_obj}").to eq('#include <header.h>')
      expect(include_obj).to eq('header.h')
    end
  end

  describe "edge cases" do
    it "raises an exception for empty string" do
      expect { SystemInclude.new("  ") }.to raise_error(ArgumentError)
    end

    it "handles include with spaces" do
      include_obj = SystemInclude.new("my header.h")
      
      expect("#{include_obj}").to eq('#include <my header.h>')
      expect(include_obj).to eq('my header.h')
    end

    it "handles include with special characters" do
      include_obj = SystemInclude.new("<header-v1.2.h>")
      
      expect("#{include_obj}").to eq("#include <header-v1.2.h>")
      expect(include_obj).to eq('header-v1.2.h')
    end
  end
end

describe "Include equality" do
  describe "UserInclude equality" do
    it "compares equal to another UserInclude with same filename" do
      include1 = UserInclude.new("header.h")
      include2 = UserInclude.new("header.h")
      
      expect(include1).to eq(include2)
      expect(include2).to eq(include1)
    end

    it "compares equal to another UserInclude with same filename but different paths" do
      include1 = UserInclude.new("path1/header.h")
      include2 = UserInclude.new("path2/header.h")
      
      expect(include1).to eq(include2)
      expect(include2).to eq(include1)
    end

    it "compares not equal to another UserInclude with same filename but different paths" do
      include1 = UserInclude.new("path1/header.h", use_path: true)
      include2 = UserInclude.new("path2/header.h", use_path: true)
      
      expect(include1).not_to eq(include2)
      expect(include2).not_to eq(include1)
    end

    it "compares not equal to another UserInclude with different filename" do
      include1 = UserInclude.new("header1.h")
      include2 = UserInclude.new("header2.h")
      
      expect(include1).not_to eq(include2)
      expect(include2).not_to eq(include1)
    end

    it "compares equal to a string with matching filename" do
      include_obj = UserInclude.new("header.h")
      
      expect(include_obj).to eq("header.h")
    end

    it "compares not equal to a string with different filename" do
      include_obj = UserInclude.new("header.h")
      
      expect(include_obj).not_to eq("other.h")
    end

    it "compares not equal to a SystemInclude with same filename" do
      user_include = UserInclude.new("header.h")
      system_include = SystemInclude.new("header.h")
      
      expect(user_include).not_to eq(system_include)
      expect(system_include).not_to eq(user_include)
    end

    # This should never really happen in actual use, but logically a MockInclude is basically a UserInclude
    it "compares equal to a MockInclude with same filename" do
      user_include = UserInclude.new("header.h")
      mock_include = MockInclude.new("header.h")
      
      expect(user_include).to eq(mock_include)
      expect(mock_include).to eq(user_include)
    end

    it "compares not equal to nil" do
      include_obj = UserInclude.new("header.h")
      
      expect(include_obj).not_to eq(nil)
    end

    it "compares not equal to other object types" do
      include_obj = UserInclude.new("header.h")
      
      expect(include_obj).not_to eq(42)
      expect(include_obj).not_to eq([])
      expect(include_obj).not_to eq({})
    end
  end

  describe "SystemInclude equality" do
    it "compares equal to another SystemInclude with same filename" do
      include1 = SystemInclude.new("stdio.h")
      include2 = SystemInclude.new("stdio.h")
      
      expect(include1).to eq(include2)
      expect(include2).to eq(include1)
    end

    it "compares equal to another SystemInclude with same filename but different paths" do
      include1 = SystemInclude.new("sys/stdio.h")
      include2 = SystemInclude.new("other/stdio.h")
      
      expect(include1).to eq(include2)
      expect(include2).to eq(include1)
    end

    it "compares not equal to another SystemInclude with same filename but different paths" do
      include1 = SystemInclude.new("sys/stdio.h", use_path: true)
      include2 = SystemInclude.new("other/stdio.h", use_path: true)
      
      expect(include1).not_to eq(include2)
      expect(include2).not_to eq(include1)
    end

    it "compares not equal to another SystemInclude with different filename" do
      include1 = SystemInclude.new("stdio.h")
      include2 = SystemInclude.new("stdlib.h")
      
      expect(include1).not_to eq(include2)
      expect(include2).not_to eq(include1)
    end

    it "compares equal to a string with matching filename" do
      include_obj = SystemInclude.new("stdio.h")
      
      expect(include_obj).to eq("stdio.h")
    end

    it "compares not equal to a string with different filename" do
      include_obj = SystemInclude.new("stdio.h")
      
      expect(include_obj).not_to eq("stdlib.h")
    end

    it "compares not equal to a UserInclude with same filename" do
      system_include = SystemInclude.new("header.h")
      user_include = UserInclude.new("header.h")
      
      expect(system_include).not_to eq(user_include)
      expect(user_include).not_to eq(system_include)
    end

    it "compares not equal to a MockInclude with same filename" do
      system_include = SystemInclude.new("header.h")
      mock_include = MockInclude.new("header.h")
      
      expect(system_include).not_to eq(mock_include)
      expect(mock_include).not_to eq(system_include)
    end

    it "compares not equal to nil" do
      include_obj = SystemInclude.new("stdio.h")
      
      expect(include_obj).not_to eq(nil)
    end

    it "compares not equal to other object types" do
      include_obj = SystemInclude.new("stdio.h")
      
      expect(include_obj).not_to eq(42)
      expect(include_obj).not_to eq([])
      expect(include_obj).not_to eq({})
    end
  end

  describe "MockInclude equality" do
    it "compares equal to another MockInclude with same filename" do
      include1 = MockInclude.new("mock_module.h")
      include2 = MockInclude.new("mock_module.h")
      
      expect(include1).to eq(include2)
      expect(include2).to eq(include1)
    end

    it "compares equal to another MockInclude with same filename but different paths" do
      include1 = MockInclude.new("mocks/mock_module.h")
      include2 = MockInclude.new("test/mocks/mock_module.h")
      
      expect(include1).to eq(include2)
      expect(include2).to eq(include1)
    end

    it "compares not equal to another MockInclude with same filename but different paths" do
      include1 = MockInclude.new("mocks/mock_module.h", use_path: true)
      include2 = MockInclude.new("test/mocks/mock_module.h", use_path: true)
      
      expect(include1).not_to eq(include2)
      expect(include2).not_to eq(include1)
    end

    it "compares not equal to another MockInclude with different filename" do
      include1 = MockInclude.new("mock_module1.h")
      include2 = MockInclude.new("mock_module2.h")
      
      expect(include1).not_to eq(include2)
      expect(include2).not_to eq(include1)
    end

    it "compares equal to a string with matching filename" do
      include_obj = MockInclude.new("mock_module.h")
      
      expect(include_obj).to eq("mock_module.h")
    end

    it "compares not equal to a string with different filename" do
      include_obj = MockInclude.new("mock_module.h")
      
      expect(include_obj).not_to eq("other_mock.h")
    end

    # This should never really happen in actual use, but logically a MockInclude is basically a UserInclude
    it "compares equal to a UserInclude with same filename" do
      mock_include = MockInclude.new("header.h")
      user_include = UserInclude.new("header.h")
      
      expect(mock_include).to eq(user_include)
      expect(user_include).to eq(mock_include)
    end

    it "compares not equal to a SystemInclude with same filename" do
      mock_include = MockInclude.new("header.h")
      system_include = SystemInclude.new("header.h")
      
      expect(mock_include).not_to eq(system_include)
      expect(system_include).not_to eq(mock_include)
    end

    it "compares not equal to nil" do
      include_obj = MockInclude.new("mock_module.h")
      
      expect(include_obj).not_to eq(nil)
    end

    it "compares not equal to other object types" do
      include_obj = MockInclude.new("mock_module.h")
      
      expect(include_obj).not_to eq(42)
      expect(include_obj).not_to eq([])
      expect(include_obj).not_to eq({})
    end
  end

  describe "hash and eql? for use in sets and hashes" do
    it "allows UserInclude objects with same filename to be deduplicated in arrays" do
      include1 = UserInclude.new("header.h")
      include2 = UserInclude.new("header.h")
      include3 = UserInclude.new("other.h")
      
      array = [include1, include2, include3]
      unique = array.uniq
      
      expect(unique.length).to eq(2)
      expect(unique).to include(include1)
      expect(unique).to include(include3)
    end

    it "allows SystemInclude objects with same filename to be deduplicated in arrays" do
      include1 = SystemInclude.new("stdio.h")
      include2 = SystemInclude.new("stdio.h")
      include3 = SystemInclude.new("stdlib.h")
      
      array = [include1, include2, include3]
      unique = array.uniq
      
      expect(unique.length).to eq(2)
      expect(unique).to include(include1)
      expect(unique).to include(include3)
    end

    it "allows MockInclude objects with same filename to be deduplicated in arrays" do
      include1 = MockInclude.new("mock_module.h")
      include2 = MockInclude.new("mock_module.h")
      include3 = MockInclude.new("mock_other.h")
      
      array = [include1, include2, include3]
      unique = array.uniq
      
      expect(unique.length).to eq(2)
      expect(unique).to include(include1)
      expect(unique).to include(include3)
    end

    it "treats UserInclude and SystemInclude with same filename as different in arrays" do
      user_include = UserInclude.new("header.h")
      system_include = SystemInclude.new("header.h")
      
      array = [user_include, system_include]
      unique = array.uniq
      
      expect(unique.length).to eq(2)
      expect(unique).to include(user_include)
      expect(unique).to include(system_include)
    end

    # This should never really happen in actual use, but logically a MockInclude is basically a UserInclude
    it "treats UserInclude and MockInclude with same filename as same in arrays" do
      user_include = UserInclude.new("header.h")
      mock_include = MockInclude.new("header.h")
      
      array = [user_include, mock_include]
      unique = array.uniq
      
      expect(unique.length).to eq(1)
      expect(unique[0]).to eq(user_include)
    end

    it "treats MockInclude and SystemInclude with same filename as different in arrays" do
      mock_include = MockInclude.new("header.h")
      system_include = SystemInclude.new("header.h")
      
      array = [mock_include, system_include]
      unique = array.uniq
      
      expect(unique.length).to eq(2)
      expect(unique).to include(mock_include)
      expect(unique).to include(system_include)
    end

    it "allows Include objects to be used as hash keys" do
      include1 = UserInclude.new("header.h")
      include2 = UserInclude.new("header.h")
      include3 = SystemInclude.new("header.h")
      
      hash = {}
      hash[include1] = "value1"
      hash[include2] = "value2"  # Should overwrite value1
      hash[include3] = "value3"  # Different type, different key
      
      expect(hash.length).to eq(2)
      expect(hash[include1]).to eq("value2")
      expect(hash[include3]).to eq("value3")
    end

    it "allows Include objects to be used in sets" do
      include1 = UserInclude.new("header.h")
      include2 = UserInclude.new("header.h")
      include3 = SystemInclude.new("header.h")
      
      set = Set.new
      set << include1
      set << include2  # Should not add duplicate
      set << include3  # Different type, should add
      
      expect(set.size).to eq(2)
      expect(set).to include(include1)
      expect(set).to include(include3)
    end
  end
end
