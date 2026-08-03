# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# End-to-end coverage of DependencyTracker's integration into the real test-build
# pipeline (content-hash-based rebuild staleness -- see lib/ceedling/dependencies/).
# Unlike the module-level specs in spec/system/dependencies/, these exercise the
# actual `ceedling` CLI against a real example project on disk, asserting on the
# presence/absence of "Compiling"/"Linking"/"Running" activity in real build output
# across a *sequence* of invocations against the *same* project directory -- proving
# a target was genuinely skipped, not merely that the build succeeded.
#
# Assertions anchor "Compiling"/"Linking"/"Running" matches to the start of a line
# (`/^Compiling /` etc.): at --verbosity=debug Ceedling's own output is large enough
# that these words turn up incidentally elsewhere (vendor file comments, help text,
# unrelated progress messages) -- an unanchored substring match produces false
# positives having nothing to do with an actual build step running.
#
# Each scenario appends a real, compiled-byte-changing statement to a source file
# rather than just touching it or adding a comment: a compiler is free to produce
# byte-identical output for a whitespace- or comment-only edit, so asserting on
# those would make these tests flaky/compiler-dependent. A `volatile int`
# declaration inside a function body (or a new function prototype at file scope,
# for header-only scenarios) is used specifically because it reliably shows up in
# compiled output across toolchains.
ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  # Inserts a real statement as the first line of a test file's setUp() body --
  # a functional change guaranteed to alter that test's compiled object, unlike
  # a comment or whitespace-only edit. Works whether setUp()'s existing body is
  # empty (standard Ceedling/Unity boilerplate) or not.
  def probe_test_file!(relative_path)
    content = File.read(relative_path)
    replaced = content.sub!(/(void setUp\(void\)\s*\{\n)/) { "#{Regexp.last_match(1)}  volatile int __ceedling_delta_probe = 1;\n" }
    raise "probe_test_file!: could not find setUp() in #{relative_path}" if replaced.nil?
    File.write(relative_path, content)
  end

  # Adds a new function prototype to a shared header, ahead of its include guard's
  # #endif -- a real content change to the header itself (affecting every source
  # file that #includes it) without needing a corresponding definition.
  def probe_header!(relative_path)
    content = File.read(relative_path)
    content.sub!(/#endif\s*(\/\/[^\n]*)?\s*\z/) { "void __ceedling_delta_probe(void);\n\n#{Regexp.last_match(0)}" }
    File.write(relative_path, content)
  end

  describe "Delta builds: incremental rebuild staleness tracking (temp_sensor)" do
    before do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("example temp_sensor")
        expect(output).to match(/created/)
      end
    end

    it "skips recompiling, relinking, and rerunning everything on an immediate rebuild with no changes, but still reports every test's cached result" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          baseline = @c.ceedling_build_exec("test:all")
          expect(baseline).to match(/TESTED:\s+86/)
          expect(baseline).to match(/PASSED:\s+86/)

          rebuild = @c.ceedling_build_exec("test:all")
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to_not match(/^Running /)

          # Nothing needed rebuilding, but every test's cached result is still
          # reported in this same run's own summary -- Generator#generate_test_results
          # reports a skipped executable's cached .pass/.fail file rather than
          # silently omitting it from the count.
          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)

          # The separate on-demand summary task, which independently re-scans
          # all result files from disk, agrees.
          summary = @c.ceedling_build_exec("summary")
          expect(summary).to match(/TESTED:\s+86/)
          expect(summary).to match(/PASSED:\s+86/)
        end
      end
    end

    it "recompiles, relinks, and reruns only the changed test (including regenerating its mocks), leaving unrelated tests untouched" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("test:all")

          probe_test_file!(File.join('test', 'adc', 'TestAdcModel.c'))

          rebuild = @c.ceedling_build_exec("test:all")

          # stage_collect_preprocessor_context's includes stand-in generation
          # overwrites an already-generated mock header with a blank placeholder
          # on any run where the *test* file's own bare-includes cache misses,
          # entirely independent of whether that mock's own antecedents
          # changed -- exercising that path here confirms the resulting stale
          # header is detected and every one of this test's mocks regenerated.
          expect(rebuild).to match(/Generating mock for TestAdcModel::TaskScheduler\.h/)
          expect(rebuild).to match(/Generating mock for TestAdcModel::TemperatureCalculator\.h/)
          expect(rebuild).to match(/Generating mock for TestAdcModel::TemperatureFilter\.h/)

          expect(rebuild).to match(/^Compiling TestAdcModel\.c/)
          expect(rebuild).to match(/^Linking TestAdcModel\.out/)
          expect(rebuild).to match(/^Running TestAdcModel\.out/)

          # The full project total (86), not just the 3 belonging to the one
          # test that actually reran -- proving the other 83 tests' cached
          # results are correctly folded into this same run's summary
          # alongside the freshly-executed ones, not just the rebuilt subset.
          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)

          # Spot check: unrelated tests (no relationship to AdcModel or its mocks)
          # show no compile, link, or mock-generation activity at all. (Context
          # extraction -- "Parsing TestUsartModel.c for..." -- legitimately runs
          # for every test every time regardless of staleness, so it's excluded
          # from these checks by scoping to Compiling/Linking/mock-generation lines.)
          expect(rebuild).to_not match(/^Compiling .*UsartModel/)
          expect(rebuild).to_not match(/^Compiling .*TimerModel/)
          expect(rebuild).to_not match(/^Linking .*Usart/)
          expect(rebuild).to_not match(/^Linking .*Timer/)
          expect(rebuild).to_not match(/Generating mock for TestUsartConductor/)
        end
      end
    end

    it "recompiles every test that includes a changed shared header, but leaves unrelated tests untouched" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("test:all")

          # AdcModel.h is #included directly by AdcModel.c, AdcConductor.c, and
          # Main.c -- so TestAdcModel, TestAdcConductor, and TestMain each
          # recompile at least one object as a result, entirely independent of
          # any test file's own content.
          probe_header!(File.join('src', 'AdcModel.h'))

          rebuild = @c.ceedling_build_exec("test:all")

          expect(rebuild).to match(/^Compiling.*AdcModel\.c/)
          expect(rebuild).to match(/^Compiling.*AdcConductor\.c/)
          expect(rebuild).to match(/^Compiling.*Main\.c/)

          # Tests with no relationship to AdcModel.h are entirely unaffected.
          expect(rebuild).to_not match(/^Compiling.*UsartModel/)
          expect(rebuild).to_not match(/^Compiling.*TimerModel/)
          expect(rebuild).to_not match(/^Compiling.*TemperatureCalculator/)
        end
      end
    end

    it "a preprocess-only meta change (no test-file edit) triggers re-extraction without recompiling anything" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("test:all")

          # A `:preprocess:`-scoped `:defines:` mixin changes the *effective*
          # preprocess defines fed into stage 4's bare-includes extraction meta
          # for every test (see Defineinator#defines: once a Hash-shaped
          # `:preprocess:` config section exists at all, files that don't match
          # one of its keys resolve to an empty list rather than falling back to
          # compile-time defines, as they do when the section is absent
          # entirely) -- without touching any test file's own content or its
          # compile-time defines/flags. Staleness here is driven entirely by
          # this meta, tracked independently of the source file's own content.
          FileUtils.mkdir_p('mixin')
          File.write('mixin/probe_preprocess_defines.yml', <<~YAML)
            ---
            :defines:
              :preprocess:
                'TestTemperatureCalculator.c':
                  - CEEDLING_DELTA_PROBE
          YAML

          rebuild = @c.ceedling_build_exec("test:all --mixin=mixin/probe_preprocess_defines.yml")

          expect(rebuild).to match(/^Extracting #includes from/)

          # Compilation is untouched -- only preprocess-time defines changed,
          # not compile-time defines/flags for any file.
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to_not match(/^Running /)

          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)
        end
      end
    end

    it "clobber removes the dependency cache and forces a full rebuild afterward" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("test:all")

          clobber = @c.ceedling_build_exec("clobber")
          expect(clobber).to_not match(/ERROR/)

          rebuild = @c.ceedling_build_exec("test:all")
          expect(rebuild).to match(/^Compiling /)
          expect(rebuild).to match(/^Linking /)
          expect(rebuild).to match(/^Running /)
          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)
        end
      end
    end

    it "a partial build (test:pattern) does not disturb the full-run cache for untouched tests" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          # Only `test:all` sets the :refresh option that permits the dependency
          # cache to prune entries for targets it didn't see this run (see
          # Dependinator#flush) -- a partial invocation like test:pattern must
          # never trigger that pruning, or a subsequent full run would
          # incorrectly treat untouched targets as needing a rebuild.
          @c.ceedling_build_exec("test:all")

          # Give the partial run something real to do -- its targets are already
          # fresh from the baseline build above, so without a change here the
          # partial run would trivially skip everything and this test would prove
          # nothing about pruning safety specifically. Both files matching the
          # [Temp] pattern are probed so the partial run has real work across its
          # whole scope, not just a subset that's itself still fresh.
          probe_test_file!(File.join('test', 'TestTemperatureCalculator.c'))
          probe_test_file!(File.join('test', 'TestTemperatureFilter.c'))

          partial = @c.ceedling_build_exec("test:pattern[Temp]")
          expect(partial).to match(/^Compiling .*TemperatureCalculator/)
          expect(partial).to match(/^Compiling .*TemperatureFilter/)
          expect(partial).to match(/TESTED:\s+6/)
          expect(partial).to match(/PASSED:\s+6/)

          # The other 80 tests the partial run never touched must still be
          # considered fresh -- proving the partial run's flush(prune: false)
          # left their cache entries alone -- while still reporting all 86
          # cached results (including the 6 the partial run just refreshed).
          rebuild = @c.ceedling_build_exec("test:all")
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to_not match(/^Running /)
          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)
        end
      end
    end
  end
end
