# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Coverage for how the system test harness translates CEEDLING_TEST_SANITIZERS
# into what Ceedling actually consumes: a CEEDLING_MIXIN_* slot holding an
# absolute path, plus the sanitizer's own runtime options in the environment the
# test executable inherits.
#
# Integration tier: these examples load the real flavor files from
# spec/support/system/sanitizers/ and exercise SystemContext's real environment
# manipulation, but spawn no subprocess and build nothing. The system suite
# itself would prove the same translation only as a side effect of a full build,
# at minutes per example instead of milliseconds, and would not be able to show
# the negative cases at all.
#
# `with_context` is reached directly rather than through a deployed project
# because its environment block is the unit under test here -- it yields with
# ENV already assembled, so the block can simply read back what it set.

require 'spec_helper'
require 'system_context'

describe 'System harness sanitizer wiring (integration)' do

  # with_context chdir's into this and restores on exit; nothing is written to it
  let(:context) { SystemContext.new }

  after do
    context.done!
    SystemContext.sanitizers_disabled = false
  end

  # Returns the ENV values with_context assembles, for just the keys this spec
  # cares about. Captured inside the block because with_constrained_env restores
  # the surrounding environment the moment it returns.
  def captured_env(flavor)
    original = ENV['CEEDLING_TEST_SANITIZERS']
    ENV['CEEDLING_TEST_SANITIZERS'] = flavor
    captured = nil
    context.with_context do
      captured = { mixin: ENV['CEEDLING_MIXIN_9'], asan: ENV['ASAN_OPTIONS'] }
    end
    captured
  ensure
    ENV['CEEDLING_TEST_SANITIZERS'] = original
  end

  context 'when CEEDLING_TEST_SANITIZERS names a flavor' do
    it 'exports the flavor mixin as an absolute path' do
      env = captured_env('asan_ubsan')

      # Absolute, not relative: each spec chdir's into its own ephemeral project
      # directory, so a relative path would resolve against that project and the
      # mixin would silently fail to be found
      expect( env[:mixin] ).to eq(File.absolute_path( env[:mixin] ))
      expect( env[:mixin] ).to end_with(File.join('sanitizers', 'asan_ubsan.yml'))
      expect( File.exist?( env[:mixin] ) ).to be(true)
    end

    it "exports the flavor's own runtime options" do
      expect( captured_env('asan_ubsan')[:asan] ).to eq('detect_leaks=0')
    end

    it 'exports the leaks flavor with leak detection on' do
      # The two flavors differ in exactly this value, which is why the flavor
      # file owns it rather than the harness
      expect( captured_env('asan_ubsan_leaks')[:asan] ).to include('detect_leaks=1')
    end
  end

  context 'when CEEDLING_TEST_SANITIZERS is unset or empty' do
    it 'exports nothing, leaving every other matrix leg untouched' do
      [nil, '', '   '].each do |value|
        env = captured_env(value)
        expect( env[:mixin] ).to be_nil
        expect( env[:asan] ).to be_nil
      end
    end
  end

  context 'when CEEDLING_TEST_SANITIZERS names no existing flavor' do
    it 'raises rather than running uninstrumented' do
      # A typo in a CI workflow must fail the job, not quietly reduce it to an
      # ordinary run that reports success while testing none of what it claims
      expect { captured_env('asan_ubsan_typo') }.to raise_error(
        SystemContext::VerificationFailed, /asan_ubsan_typo/
      )
    end
  end

  context 'when a spec opts out' do
    it 'exports nothing even with a valid flavor selected' do
      SystemContext.sanitizers_disabled = true
      env = captured_env('asan_ubsan')
      expect( env[:mixin] ).to be_nil
      expect( env[:asan] ).to be_nil
    end
  end

end
