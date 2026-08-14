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
  # file that #includes it) without needing a corresponding definition. Matches
  # both a trailing `// GUARD` and `/* GUARD */` comment on the #endif line.
  def probe_header!(relative_path)
    content = File.read(relative_path)
    content.sub!(/#endif\s*(\/\/[^\n]*|\/\*.*?\*\/)?\s*\z/) { "void __ceedling_delta_probe(void);\n\n#{Regexp.last_match(0)}" }
    File.write(relative_path, content)
  end

  # Inserts a real statement as the first line of a named function's body in a
  # plain source file -- the same kind of functional, compiled-byte-changing
  # edit as probe_test_file!, but targeting an arbitrary function rather than
  # the fixed setUp() convention.
  def probe_source_file!(relative_path, function_name)
    content = File.read(relative_path)
    replaced = content.sub!(/(#{Regexp.escape(function_name)}\([^)]*\)\s*\{\n)/) { "#{Regexp.last_match(1)}  volatile int __ceedling_delta_probe = 1;\n" }
    raise "probe_source_file!: could not find #{function_name}(...) in #{relative_path}" if replaced.nil?
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

    it "recompiles, relinks, and reruns only the changed test, without regenerating mocks that didn't actually change, leaving unrelated tests untouched" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("test:all")

          probe_test_file!(File.join('test', 'adc', 'TestAdcModel.c'))

          rebuild = @c.ceedling_build_exec("test:all")

          # The test file's own bare-includes cache misses (its content changed),
          # which drives stage_collect_preprocessor_context's includes stand-in
          # generation for this test's mocked headers -- but that stand-in step
          # skips writing over an already-generated mock header rather than
          # blanking it out (see TestBuildSetup#generate_test_includes_standins),
          # so none of this test's mocks are considered stale purely from that
          # unrelated cache miss. Only a change to the header a mock actually
          # mocks, or to the mock's own config meta, can make it regenerate.
          expect(rebuild).to_not match(/Generating mock for TestAdcModel::TaskScheduler\.h/)
          expect(rebuild).to_not match(/Generating mock for TestAdcModel::TemperatureCalculator\.h/)
          expect(rebuild).to_not match(/Generating mock for TestAdcModel::TemperatureFilter\.h/)

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

          # A `:preprocess:`-scoped `:defines:` project.yml edit changes the
          # *effective* preprocess defines fed into stage 4's bare-includes
          # extraction meta, but only for the one file matching this new
          # matcher -- every other file falls back to its own compile-time
          # defines exactly as if the `:preprocess:` section didn't exist for
          # it (see ConfigMatchinator#matches?'s `no_match_default`), so only
          # TestTemperatureCalculator.c's meta actually changes here, without
          # touching any test file's own content or compile-time defines/flags.
          @c.merge_project_yml_for_test({
            :defines => {
              :preprocess => {
                'TestTemperatureCalculator.c' => ['CEEDLING_DELTA_PROBE']
              }
            }
          })

          rebuild = @c.ceedling_build_exec("test:all")

          expect(rebuild).to match(/^Extracting #includes from TestTemperatureCalculator\.c/)

          # Unrelated files' meta is untouched -- proving the no_match_default
          # fallback, not just the matched file's own re-extraction.
          expect(rebuild).to_not match(/^Extracting #includes from TestUsartModel/)
          expect(rebuild).to_not match(/^Extracting #includes from TestTimerModel/)
          expect(rebuild).to_not match(/^Extracting #includes from TestTemperatureFilter/)

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
          # Only `test:all` sets the :refresh_dependencies option that permits the
          # dependency cache to prune entries for targets it didn't see this run (see
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

  # Partials preprocessing (stages 6-8) gates its directives-only/preserve-macros/
  # full-expansion passes on their own DependencyTracker targets, one per partial
  # header and one per partial source -- separate from (and in addition to) the
  # object-compile staleness every test already has. wondrous_forest exercises
  # both an implementation-only partial (SoilMoisture, no interface) and an
  # implementation+interface partial (ForestMonitor), so this project also proves
  # that distinction survives an untouched rebuild.
  describe "Delta builds: incremental rebuild staleness tracking (wondrous_forest, Partials)" do
    before do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("example wondrous_forest")
        expect(output).to match(/created/)
      end
    end

    it "skips recompiling, relinking, rerunning, and regenerating any partial or mock on an immediate rebuild with no changes" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          baseline = @c.ceedling_build_exec("test:all")
          expect(baseline).to match(/TESTED:\s+67/)
          expect(baseline).to match(/PASSED:\s+67/)

          rebuild = @c.ceedling_build_exec("test:all")
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to_not match(/^Running /)
          expect(rebuild).to_not match(/Generating mock for/)
          expect(rebuild).to_not match(/Generating shared Partial types for/)
          expect(rebuild).to_not match(/Generating Partial implementation for/)
          expect(rebuild).to_not match(/Generating Partial mockable interface for/)

          expect(rebuild).to match(/TESTED:\s+67/)
          expect(rebuild).to match(/PASSED:\s+67/)
        end
      end
    end

    it "reprocesses only the changed partial's source, leaving its header, other partials, and unrelated tests untouched" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          @c.ceedling_build_exec("test:all")

          probe_source_file!(File.join('src', 'SoilMoisture.c'), 'SoilMoisture_Init')

          rebuild = @c.ceedling_build_exec("test:all")

          expect(rebuild).to match(/^Compiling TestSoilMoisture::SoilMoisture\.c/)
          expect(rebuild).to match(/^Linking TestSoilMoisture\.out/)
          expect(rebuild).to match(/^Running TestSoilMoisture\.out/)

          # Other partials -- implementation-only (EventQueue) and
          # implementation+interface (ForestMonitor) alike -- show no activity.
          expect(rebuild).to_not match(/^Compiling.*EventQueue/)
          expect(rebuild).to_not match(/^Compiling.*ForestMonitor/)
          expect(rebuild).to_not match(/^Linking TestEventQueue/)
          expect(rebuild).to_not match(/^Linking TestForestMonitor/)

          expect(rebuild).to match(/TESTED:\s+67/)
          expect(rebuild).to match(/PASSED:\s+67/)
        end
      end
    end

    it "reprocesses only the changed partial's header, leaving its source, other partials, and unrelated tests untouched" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          @c.ceedling_build_exec("test:all")

          # ForestMonitor.c #includes ForestMonitor.h directly, so this also
          # exercises the pre-existing shared-header compile staleness path
          # (proving it's unaffected by Partials' own separate DependencyTracker
          # targets for the header/source preprocessing passes) alongside the
          # header partial-preprocessing target itself. As with the equivalent
          # temp_sensor scenario above, only Compiling is asserted here -- a
          # bare added prototype with no call site can compile to an object
          # identical to the prior one, in which case linking is correctly
          # skipped on its own separate content-hash staleness check.
          probe_header!(File.join('src', 'ForestMonitor.h'))

          rebuild = @c.ceedling_build_exec("test:all")

          expect(rebuild).to match(/^Compiling TestForestMonitor::ForestMonitor\.c/)

          expect(rebuild).to_not match(/^Compiling.*SoilMoisture/)
          expect(rebuild).to_not match(/^Compiling.*TemperatureSensor/)
          expect(rebuild).to_not match(/^Linking TestSoilMoisture/)
          expect(rebuild).to_not match(/^Linking TestTemperatureSensor/)

          expect(rebuild).to match(/TESTED:\s+67/)
          expect(rebuild).to match(/PASSED:\s+67/)
        end
      end
    end

    it "a preprocess-only meta change (no file edit) triggers re-extraction across partials without recompiling anything" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          @c.ceedling_build_exec("test:all")

          # As with the equivalent temp_sensor scenario above, introducing a
          # Hash-shaped :preprocess: defines section changes effective
          # preprocess defines meta only for the one file matching it -- every
          # other file falls back to its own compile-time defines (see
          # ConfigMatchinator#matches?'s `no_match_default`), so only
          # TestSoilMoisture.c's bare-includes extraction goes stale here.
          # Partials' own required macro symbol (CEEDLING_PARTIALS_PREFIX) is
          # delivered unconditionally by TestBuildSetup#framework_defines
          # regardless of this section, so it's unaffected either way.
          @c.merge_project_yml_for_test({
            :defines => {
              :preprocess => {
                'TestSoilMoisture.c' => ['CEEDLING_DELTA_PROBE']
              }
            }
          })

          rebuild = @c.ceedling_build_exec("test:all")

          expect(rebuild).to match(/^Extracting #includes from TestSoilMoisture\.c/)

          # Unrelated files' meta is untouched -- proving the no_match_default
          # fallback, not just the matched file's own re-extraction.
          expect(rebuild).to_not match(/^Extracting #includes from TestEventQueue/)
          expect(rebuild).to_not match(/^Extracting #includes from TestUartDriver/)

          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to_not match(/^Running /)

          expect(rebuild).to match(/TESTED:\s+67/)
          expect(rebuild).to match(/PASSED:\s+67/)
        end
      end
    end
  end

  # cipher_quest is the only example project with :release_build: TRUE. Its release
  # build normally needs a --mixin to supply :defines ↳ :release (feature symbols
  # main.c's conditional compilation requires) -- these scenarios instead merge
  # those defines directly into project.yml, matching this file's own established
  # pattern elsewhere, so they don't depend on mixin flags at all.
  describe "Delta builds: incremental rebuild staleness tracking (cipher_quest, Release)" do
    before do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("example cipher_quest")
        expect(output).to match(/created/)
      end
    end

    # Merges :defines ↳ :release directly into cipher_quest's project.yml, standing
    # in for the --mixin flag the example otherwise expects -- must run inside the
    # project directory, so each `it` calls this itself rather than sharing a
    # `before` (project.yml doesn't exist until the project directory is entered).
    def enable_release_features!
      @c.merge_project_yml_for_test({
        :defines => {
          :release => ['CIPHER_ROT13', 'CIPHER_CAESAR', 'ANALYZER_ENABLED']
        }
      })
    end

    it "skips recompiling and relinking on an immediate rebuild with no changes" do
      @c.with_context do
        Dir.chdir "cipher_quest" do
          enable_release_features!

          baseline = @c.ceedling_build_exec("release")
          expect(baseline).to_not match(/ERROR/)

          rebuild = @c.ceedling_build_exec("release")
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
        end
      end
    end

    it "recompiles and relinks only the object whose source changed" do
      @c.with_context do
        Dir.chdir "cipher_quest" do
          enable_release_features!
          @c.ceedling_build_exec("release")

          probe_source_file!(File.join('src', 'cipher.c'), 'cipher_rot13')

          rebuild = @c.ceedling_build_exec("release")

          expect(rebuild).to match(/^Compiling cipher\.c/)
          expect(rebuild).to match(/^Linking /)

          expect(rebuild).to_not match(/^Compiling analyzer\.c/)
          expect(rebuild).to_not match(/^Compiling text_utils\.c/)
          expect(rebuild).to_not match(/^Compiling main\.c/)
        end
      end
    end

    it "recompiles every object whose source #includes a changed header, via .d-file-derived transitive tracking, leaving unrelated objects untouched" do
      @c.with_context do
        Dir.chdir "cipher_quest" do
          enable_release_features!
          @c.ceedling_build_exec("release")

          # analyzer.h is #included by both analyzer.c and main.c, so both
          # objects' registered dependencies -- populated from each object's own
          # `.d` file, discovered by gcc's -MMD -MF during its prior compile --
          # include analyzer.h; its content hash changing makes both objects
          # stale, independent of either .c file's own content. Only Compiling
          # is asserted (not Linking): a bare added prototype with no call site
          # can compile to an object identical to the prior one, in which case
          # linking is correctly skipped on its own separate content-hash
          # staleness check.
          probe_header!(File.join('src', 'analyzer.h'))

          rebuild = @c.ceedling_build_exec("release")

          expect(rebuild).to match(/^Compiling analyzer\.c/)
          expect(rebuild).to match(/^Compiling main\.c/)

          expect(rebuild).to_not match(/^Compiling cipher\.c/)
          expect(rebuild).to_not match(/^Compiling text_utils\.c/)
        end
      end
    end

    it "release:compile:<file> rebuilds only that object and does not link" do
      @c.with_context do
        Dir.chdir "cipher_quest" do
          enable_release_features!
          @c.ceedling_build_exec("release")

          probe_source_file!(File.join('src', 'cipher.c'), 'cipher_rot13')

          rebuild = @c.ceedling_build_exec("release:compile:cipher.c")

          expect(rebuild).to match(/^Compiling cipher\.c/)
          expect(rebuild).to_not match(/^Linking /)
        end
      end
    end
  end
end
