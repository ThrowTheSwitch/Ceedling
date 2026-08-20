# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_invoker_types'

describe "TestInvokerTypes" do
  describe TestInvokerTypes::Testable do
    it "defaults partials to a fresh, empty TestablePartials" do
      testable = TestInvokerTypes::Testable.new( :name => 'a_test', :filepath => 'test/TestFoo.c' )

      expect(testable.partials).to eq(
        TestInvokerTypes::TestablePartials.new( configs: {}, tests: [], mocks: [] )
      )
    end

    it "gives each instance its own partials, not a shared default" do
      a = TestInvokerTypes::Testable.new
      b = TestInvokerTypes::Testable.new

      a.partials.tests << 'Foo'

      expect(b.partials.tests).to eq( [] )
    end

    it "defaults mock_search_paths to an empty array" do
      testable = TestInvokerTypes::Testable.new

      expect(testable.mock_search_paths).to eq( [] )
    end

    it "accepts an explicit partials value instead of defaulting" do
      partials = TestInvokerTypes::TestablePartials.new( configs: { 'Foo' => double("Config") }, tests: ['Foo'], mocks: [] )
      testable = TestInvokerTypes::Testable.new( :partials => partials )

      expect(testable.partials).to equal( partials )
    end
  end

  describe TestInvokerTypes::PipelineState do
    it "defaults options to an empty array" do
      state = TestInvokerTypes::PipelineState.new( :testables => {} )

      expect(state.options).to eq( [] )
    end

    it "accepts an explicit options value instead of defaulting" do
      state = TestInvokerTypes::PipelineState.new( :testables => {}, :options => [:build_only] )

      expect(state.options).to eq( [:build_only] )
    end
  end

  describe TestInvokerTypes::MockDetails do
    it "carries a resolved mock's name, locations, and compiler input" do
      details = TestInvokerTypes::MockDetails.new(
        name: 'MockFoo', filepath: 'src/drivers/foo.h', path: 'drivers', source: 'src/drivers/foo.h', input: 'src/drivers/foo.h'
      )

      expect(details.name).to eq( 'MockFoo' )
      expect(details.filepath).to eq( 'src/drivers/foo.h' )
      expect(details.path).to eq( 'drivers' )
      expect(details.source).to eq( 'src/drivers/foo.h' )
      expect(details.input).to eq( 'src/drivers/foo.h' )
    end
  end

  describe TestInvokerTypes::RunnerInfo do
    it "carries a test runner's generated output and its own input file" do
      runner = TestInvokerTypes::RunnerInfo.new(
        output_filepath: 'build/test/runners/a_test/TestFoo_runner.c', input_filepath: 'test/TestFoo.c'
      )

      expect(runner.output_filepath).to eq( 'build/test/runners/a_test/TestFoo_runner.c' )
      expect(runner.input_filepath).to eq( 'test/TestFoo.c' )
    end
  end

  describe TestInvokerTypes::PartialWork do
    it "carries a partial file's config and owning testable, with staleness fields settable after construction" do
      config   = double("Config")
      testable = TestInvokerTypes::Testable.new( name: 'a_test' )
      work     = TestInvokerTypes::PartialWork.new( config: config, testable: testable, directives_only_filepath: nil )

      work.preprocessed_target = 'build/preprocess/Foo.h'
      work.stale               = true

      expect(work.config).to equal( config )
      expect(work.testable).to equal( testable )
      expect(work.preprocessed_target).to eq( 'build/preprocess/Foo.h' )
      expect(work.stale).to be true
    end
  end

  describe TestInvokerTypes::MockWork do
    it "carries a mock's own details and owning testable, with staleness fields settable after construction" do
      details  = TestInvokerTypes::MockDetails.new( name: 'MockFoo' )
      testable = TestInvokerTypes::Testable.new( name: 'a_test' )
      work     = TestInvokerTypes::MockWork.new( name: :MockFoo, details: details, testable: testable, directives_only_filepath: nil )

      work.preprocessed_target = 'build/preprocess/MockFoo.h'
      work.stale               = false

      expect(work.name).to eq( :MockFoo )
      expect(work.details).to equal( details )
      expect(work.testable).to equal( testable )
      expect(work.preprocessed_target).to eq( 'build/preprocess/MockFoo.h' )
      expect(work.stale).to be false
    end
  end

  describe TestInvokerTypes::Stage do
    describe "#enabled? and #empty?" do
      it "is enabled whenever its condition returns true, regardless of empty_condition" do
        stage = TestInvokerTypes::Stage.new(
          name: 'A stage', condition: ->(_s) { true }, empty_condition: ->(_s) { true }, body: ->(_s) {}
        )

        expect(stage.enabled?( nil )).to be true
      end

      it "is not enabled when its condition returns false" do
        stage = TestInvokerTypes::Stage.new( name: 'A stage', condition: ->(_s) { false }, body: ->(_s) {} )

        expect(stage.enabled?( nil )).to be false
      end

      it "is never empty when given no empty_condition" do
        stage = TestInvokerTypes::Stage.new( name: 'A stage', body: ->(_s) {} )

        expect(stage.empty?( nil )).to be false
      end

      it "is empty only when its empty_condition returns true" do
        stage = TestInvokerTypes::Stage.new(
          name: 'A stage', empty_condition: ->(s) { s.mocks_list.empty? }, body: ->(_s) {}
        )

        expect(stage.empty?( TestInvokerTypes::PipelineState.new( mocks_list: [] ) )).to be true
        expect(stage.empty?( TestInvokerTypes::PipelineState.new( mocks_list: [double("Mock")] ) )).to be false
      end

      it "remains enabled even when empty" do
        stage = TestInvokerTypes::Stage.new(
          name: 'A stage',
          condition:       ->(_s) { true },
          empty_condition: ->(s) { s.mocks_list.empty? },
          body:            ->(_s) {}
        )
        state = TestInvokerTypes::PipelineState.new( mocks_list: [] )

        expect(stage.enabled?( state )).to be true
        expect(stage.empty?( state )).to be true
      end

      it "is disabled regardless of whether it would otherwise have work to do" do
        stage = TestInvokerTypes::Stage.new(
          name: 'A stage',
          condition:       ->(_s) { false },
          empty_condition: ->(s) { s.mocks_list.empty? },
          body:            ->(_s) {}
        )
        state = TestInvokerTypes::PipelineState.new( mocks_list: [double("Mock")] )

        expect(stage.enabled?( state )).to be false
      end
    end
  end
end
