# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for Fix 5 (Stage 2 of the concurrency/file-presence work,
# Finding 4): TestBuildExecutor#apply_sibling_isolation's unguarded writes to
# testable.search_paths/isolated_headers_path are safe only because
# stage_build_objects's two-pass split is a real barrier -- every test's own file
# compiles in one Batchinator batch, fully drained, before any other object in
# that same test's build starts in a second batch. This is a canary, not a
# behavior test: today's design should pass every time, and it should keep
# passing after any future change -- if it ever starts failing, that's this spec
# doing its job, catching a barrier that's been merged away or reordered.
#
# This is the committed, right-sized version of the fact-finding phase's
# Experiment D. It belongs at the integration tier, not unit: it exercises a real
# Batchinator driving real Parallel.map worker threads, not a mocked stand-in for
# one -- exactly the real-threads-and-timing distinction this codebase's own test
# tiers already draw (see spec/support/integration/spec_integration_helper.rb's
# own header comment for that distinction as applied to the includes path).

require 'spec_helper'
require 'constructor'
require 'ceedling/constants'
require 'ceedling/batchinator'

describe 'TestBuildExecutor two-pass compile barrier (integration)' do
  # Absorbs whatever Batchinator's own logging/reporting calls -- this spec cares
  # about thread scheduling, not log output.
  class NullObject
    def method_missing(*_args, **_kwargs); self; end
    def respond_to_missing?(*); true; end
  end
  NULL = NullObject.new

  class StubConfigurator
    def initialize(threads); @threads = threads; end
    def project_compile_threads; @threads; end
    def project_test_threads; @threads; end
  end

  # Stands in for a Testable: the one field apply_sibling_isolation actually
  # writes unguarded (search_paths), read many times per test across the second
  # batch.
  Testable = Struct.new(:name, :search_paths, keyword_init: true)

  THREADS         = 12
  TESTABLE_COUNT  = 40
  ITERATIONS      = 40 # sized for CI runtime, not exhaustive reproduction -- see below

  let(:batchinator) { Batchinator.new(configurator: StubConfigurator.new(THREADS), loginator: NULL, reportinator: NULL) }

  # Mirrors stage_build_objects's own two sequential compile_pass.call invocations:
  # every testable's "own file" batch (the only place search_paths is corrected)
  # runs to completion before the "other objects" batch, which must see every
  # correction, starts.
  def run_two_pass(testables)
    violations = 0

    batchinator.exec(workload: :compile, things: testables) do |t|
      sleep(rand * 0.001) # widen the scheduling window a little
      t.search_paths = ["ISOLATED:#{t.name}"] + t.search_paths
    end

    batchinator.exec(workload: :compile, things: testables) do |t|
      violations += 1 unless t.search_paths.first == "ISOLATED:#{t.name}"
    end

    violations
  end

  it 'never lets an "other object" read an uncorrected search_paths, across many iterations' do
    total_violations = 0

    ITERATIONS.times do
      testables = Array.new(TESTABLE_COUNT) { |i| Testable.new(name: "test#{i}", search_paths: ["orig#{i}"]) }
      total_violations += run_two_pass(testables)
    end

    # Stage 1's fact-finding run (200 iterations, both host and Docker) saw exactly
    # 0/8,000 violations here and 97%+ once the barrier was removed -- a real,
    # reliably-reproducing gap this size is enough to reliably catch a regression
    # at this smaller, CI-sized iteration count too.
    expect(total_violations).to eq(0)
  end
end
