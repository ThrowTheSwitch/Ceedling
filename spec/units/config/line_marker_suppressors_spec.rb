# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Finding the preprocessor options that suppress line markers, wherever configuration
# hands them to test preprocessing. ConfiguratorSetup#validate_line_markers reports what
# this finds; configurator_setup_spec.rb covers that reporting.

require 'spec_helper'
require 'ceedling/config/line_marker_suppressors'

describe LineMarkerSuppressors do

  context ".in_flags" do
    it "finds -P in a context's :preprocess list" do
      flags = { test: { preprocess: ['-std=c99', '-P'] } }

      expect(described_class.in_flags( flags, [:test] )).to eq( [ [[:flags, :test, :preprocess], '-P'] ] )
    end

    # Test preprocessing uses compile flags wherever no :preprocess flags apply
    it "finds --no-line-commands in a :compile matcher's list, naming the matcher" do
      flags = { test: { compile: { '/Adc/' => ['--no-line-commands'] } } }

      expect(described_class.in_flags( flags, [:test] )).to eq( [ [[:flags, :test, :compile, '/Adc/'], '--no-line-commands'] ] )
    end

    it "finds an option among others in one entry, and one passed through -Wp," do
      flags = { test: { preprocess: ['-Wall -P', '-Wp,-MD,deps.d,-P'] } }

      expect(described_class.in_flags( flags, [:test] ).map( &:last )).to eq( ['-Wall -P', '-Wp,-MD,deps.d,-P'] )
    end

    it "matches whole options only" do
      flags = { test: { preprocess: ['-pedantic', '-Wpedantic', '-MP', '-fPIC', '-Pfoo', '-Wp,-MD,deps.d'] } }

      expect(described_class.in_flags( flags, [:test] )).to eq( [] )
    end

    it "reads the contexts it is given, plugin contexts among them, and no others" do
      flags = { gcov: { compile: ['-P'] }, release: { compile: ['-P'] } }

      expect(described_class.in_flags( flags, [:test, :gcov] )).to eq( [ [[:flags, :gcov, :compile], '-P'] ] )
    end

    it "ignores matcher keys and operations other than :preprocess and :compile" do
      flags = { test: { compile: { '-P' => ['-g'] }, link: ['-P'] } }

      expect(described_class.in_flags( flags, [:test] )).to eq( [] )
    end

    # validate_flags reports a malformed section; this must only not trip over one
    it "tolerates malformed flags" do
      [nil, [], 'string', { test: 'string' }, { test: { compile: 7 } }, { test: { compile: { '/x/' => 7 } } }].each do |flags|
        expect(described_class.in_flags( flags, [:test] )).to eq( [] )
      end
    end
  end

  context ".in_tools" do
    def config(arguments, shortcut: nil)
      config = { tools: { test_file_full_preprocessor: { arguments: arguments } } }
      config[:tools_test_file_full_preprocessor] = { arguments: shortcut } unless shortcut.nil?
      return config
    end

    it "finds an option in a preprocessor tool's arguments" do
      expect(described_class.in_tools( config( ['-E', '-P', '"${1}"'] ) )).to eq( [ [[:tools, :test_file_full_preprocessor, :arguments], '-P'] ] )
    end

    # The merged tool holds the shortcut's arguments, but the user wrote them in the shortcut
    it "names the :tools_<name> shortcut that added the option" do
      found = described_class.in_tools( config( ['-E', '--no-line-commands'], shortcut: ['--no-line-commands'] ) )

      expect(found).to eq( [ [[:tools_test_file_full_preprocessor, :arguments], '--no-line-commands'] ] )
    end

    # A bare-includes make rule has no line markers to lose
    it "leaves the bare-includes tool alone and skips arguments that aren't strings" do
      config = { tools: { test_bare_includes_preprocessor: { arguments: ['-P'] }, test_file_directives_only_preprocessor: { arguments: [{ '-P' => 1 }] } } }

      expect(described_class.in_tools( config )).to eq( [] )
    end
  end

end
