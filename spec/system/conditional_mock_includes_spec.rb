# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Conditional mock #includes
## ==========================
##
## A test's mocks are the ones its build actually uses, so with test preprocessing the
## preprocessor decides them, not a plain scan of the test file. Two shapes show it:
##
## - A mock in an #if branch that is off, whose header does not exist (issue #1083,
##   Case 1). Only the final branch can build in this project.
## - A mock a macro names, whose header sits in a subdirectory. Only the preprocessor
##   sees that #include, and the mock is generated into a mirrored directory the
##   compiler must search.
## - A mock chosen by a macro its other mock's header defines (issue #1083, Case 2).
##   The macro is visible only through that header, which a mock's stand-in includes.
##
## Each shape's variations run in spec/integration/test_includes_extractinator_spec.rb;
## these examples carry the reported shapes through a whole build.
##
## Without test preprocessing, every #include is read as written, so the missing
## header stops the build. Fallback preprocessing, forced here so every toolchain runs
## it, reconciles against a plain expansion as a best effort, which handles this shape.
##
## Assets: assets/fixtures/tests_with_conditional_mocks/
##

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "cond_mock"

  before(:all) { @directives_only = directives_only_supported? }

  CONDITIONAL_MOCKS_FIXTURE = 'tests_with_conditional_mocks'.freeze

  def prepare(files, mode, fallback: false)
    in_project do
      files.each { |file| copy_fixture( "#{CONDITIONAL_MOCKS_FIXTURE}/#{file}", File.dirname( file ) ) }
      @c.merge_project_yml_for_test(
        :project    => { :use_test_preprocessor => mode },
        :test_build => { :preprocess_force_fallback => fallback },
        :cmock      => { :mock_prefix => 'mock_' }
      )
    end
  end

  def build
    output = nil
    in_project { output = @c.ceedling_build_exec( 'test:all' ) }
    return output
  end

  describe "a mock in an #if branch that is off, without a header" do
    let(:files) { %w[src/Gpt.h src/Case_01.h src/Case_01.c test/test_Case_01.c] }

    [:tests, :all].each do |mode|
      it "builds with :#{mode} preprocessing, mocking only the branch that is on" do
        skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
        prepare( files, mode )

        output = build
        expect(@c.last_exit_status).to eq( 0 ), output
        expect(output).to match( /PASSED:\s+1/ )
      end

      it "builds with :#{mode} fallback preprocessing, mocking only the branch that is on" do
        prepare( files, mode, fallback: true )

        output = build
        expect(@c.last_exit_status).to eq( 0 ), output
        expect(output).to match( /PASSED:\s+1/ )
      end
    end

    it "builds with :all preprocessing when a branch that is off names its mock in the wrong letter case" do
      skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
      prepare( %w[src/Gpt.h src/Case_01.h src/Case_01.c test/test_Case_01_legacy.c], :all )

      output = build
      expect(@c.last_exit_status).to eq( 0 ), output
      expect(output).to match( /PASSED:\s+1/ )
    end

    it "stops the build naming the missing header without test preprocessing" do
      prepare( files, :none )

      output = build
      expect(@c.last_exit_status).to_not eq( 0 )
      expect(output).to include( 'Found no file `Gpt_HwType1.h`' )
    end
  end

  describe "a mock chosen by a macro its other mock's header defines" do
    let(:files) { %w[src/MyModuleConfig.h src/MyModulePart1.h src/MyModulePart2.h src/Case_02.h src/Case_02.c test/test_Case_02.c] }

    it "builds with :all preprocessing, mocking the module the macro enables" do
      skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
      prepare( files, :all )

      output = build
      expect(@c.last_exit_status).to eq( 0 ), output
      expect(output).to match( /PASSED:\s+1/ )
    end

    # Stage 4's preprocessing is skipped when nothing it read changed, so it must count
    # the mocked header among what it read
    it "builds again with :all preprocessing after only the header enables another module" do
      skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
      prepare( files, :all )

      output = build
      expect(@c.last_exit_status).to eq( 0 ), output

      in_project do
        config = File.read( 'src/MyModuleConfig.h' ).sub( '//#define MODULE_2_ENABLED', '#define MODULE_2_ENABLED' )
        File.write( 'src/MyModuleConfig.h', config )
      end

      output = build
      expect(@c.last_exit_status).to eq( 0 ), output
      expect(output).to match( /PASSED:\s+1/ )

      # The runner initializes and verifies the newly enabled module's mock
      in_project do
        expect(File.read( 'build/test/runners/test_Case_02_runner.c' )).to include( 'mock_MyModulePart2' )
      end
    end

    # Case 1 and Case 2 together, as the issue's project had them
    it "builds with :all preprocessing when the disabled module's header doesn't exist" do
      skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
      prepare( files - ['src/MyModulePart2.h'], :all )

      output = build
      expect(@c.last_exit_status).to eq( 0 ), output
      expect(output).to match( /PASSED:\s+1/ )
    end
  end

  # Test file preprocessing is skipped when nothing it read changed, so it must count
  # the headers the test includes among what it read
  describe "a test case a header's macro enables" do
    it "runs after only the header enables it, with :all preprocessing" do
      skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
      prepare( %w[src/FeatureConfig.h test/test_FeatureConfig.c], :all )

      output = build
      expect(output).to match( /TESTED:\s+1/ ), output

      in_project do
        File.write( 'src/FeatureConfig.h', File.read( 'src/FeatureConfig.h' ).sub( '//#define FEATURE_X', '#define FEATURE_X' ) )
      end

      output = build
      expect(@c.last_exit_status).to eq( 0 ), output
      expect(output).to match( /TESTED:\s+2/ )
    end
  end

  describe "a mock a macro names, with its header in a subdirectory" do
    let(:files) { %w[src/drivers/widget.h src/reader.h src/reader.c test/test_reader.c] }

    [:tests, :all].each do |mode|
      it "builds with :#{mode} preprocessing" do
        skip 'gcc ignores -fdirectives-only, so the scanned #includes are never reconciled' unless @directives_only
        prepare( files, mode )

        output = build
        expect(@c.last_exit_status).to eq( 0 ), output
        expect(output).to match( /PASSED:\s+1/ )
      end
    end
  end

end
