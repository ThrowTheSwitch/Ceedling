# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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