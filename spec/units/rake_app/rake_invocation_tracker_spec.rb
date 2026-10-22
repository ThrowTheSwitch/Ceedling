# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/rake_app/rake_task_registry'
require 'ceedling/rake_app/rake_invocation_tracker'

describe RakeInvocationTracker do
  before(:each) do
    @rake_task_registry = double('rake_task_registry')
    @rake_utils = double('rake_utils')

    @tracker = described_class.new({
      :rake_task_registry => @rake_task_registry,
      :rake_utils         => @rake_utils,
    })
  end

  describe '#test_build_invoked?' do
    it 'returns false without consulting rake_utils when no namespaces carry the test tag' do
      allow(@rake_task_registry).to receive(:namespaces_for_tag)
        .with(RakeTaskRegistry::TAG_TEST)
        .and_return([])
      expect(@rake_utils).to_not receive(:task_invoked?)

      expect(@tracker.test_build_invoked?).to eq(false)
    end

    it 'builds an alternation pattern from registered test-tagged namespaces and delegates to rake_utils' do
      allow(@rake_task_registry).to receive(:namespaces_for_tag)
        .with(RakeTaskRegistry::TAG_TEST)
        .and_return(['test', 'gcov'])
      allow(@rake_utils).to receive(:task_invoked?)
        .with(/^(test|gcov)(:|$)/)
        .and_return(true)

      expect(@tracker.test_build_invoked?).to eq(true)
    end

    it 'escapes a namespace containing a regex metacharacter before building the pattern' do
      allow(@rake_task_registry).to receive(:namespaces_for_tag)
        .with(RakeTaskRegistry::TAG_TEST)
        .and_return(['weird.name'])
      allow(@rake_utils).to receive(:task_invoked?)
        .with(/^(weird\.name)(:|$)/)
        .and_return(false)

      expect(@tracker.test_build_invoked?).to eq(false)
    end
  end

  describe '#test_task_invoked?' do
    it "delegates to rake_utils with a fixed /^test(:|$)/ pattern, passing the return value through" do
      allow(@rake_utils).to receive(:task_invoked?).with(/^test(:|$)/).and_return(true)

      expect(@tracker.test_task_invoked?).to eq(true)
    end
  end

  describe '#release_build_invoked?' do
    it 'returns false without consulting rake_utils when no namespaces carry the release tag' do
      allow(@rake_task_registry).to receive(:namespaces_for_tag)
        .with(RakeTaskRegistry::TAG_RELEASE)
        .and_return([])
      expect(@rake_utils).to_not receive(:task_invoked?)

      expect(@tracker.release_build_invoked?).to eq(false)
    end

    it 'builds an alternation pattern from registered release-tagged namespaces and delegates to rake_utils' do
      allow(@rake_task_registry).to receive(:namespaces_for_tag)
        .with(RakeTaskRegistry::TAG_RELEASE)
        .and_return(['release'])
      allow(@rake_utils).to receive(:task_invoked?)
        .with(/^(release)(:|$)/)
        .and_return(true)

      expect(@tracker.release_build_invoked?).to eq(true)
    end
  end

  describe '#invoked?' do
    it 'passes the given regex directly through to rake_utils#task_invoked?, unchanged' do
      pattern = /^clobber$/
      allow(@rake_utils).to receive(:task_invoked?).with(pattern).and_return(true)

      expect(@tracker.invoked?(pattern)).to eq(true)
    end
  end
end
