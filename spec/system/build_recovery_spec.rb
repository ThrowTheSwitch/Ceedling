# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Recovery from a bad build
## =========================
##
## A build can go wrong three ways that Ceedling must recover from on its own: an
## artifact damaged between runs, a project broken and then repaired, and a build
## interrupted in flight. In every case the builds that follow must converge on what a
## clean build produces, and stay there, without a clobber.
##
## The cases come from fault-injection stress testing. Each damaged-artifact case left
## every later build failing before Ceedling learned to track the artifact:
##
##   - a cached test result that is truncated or emptied
##   - a dependency file that names a directory, as a truncated one can
##   - a test's cached build directives, deleted or emptied
##   - a generated mock header that is truncated
##
## The broken-project and interrupted-build cases never failed, and guard that they stay
## that way. A broken build must fail the same way every time, never alternating, and
## the repaired build must match a clean one.
##
## The project mocks a header and pulls a source in through TEST_SOURCE_FILE(), so a
## build directive dropped from a damaged cache shows up as a link failure.
##

RECOVERY_ADDER_H = <<~C
  #ifndef ADDER_H
  #define ADDER_H

  int adder_add(int a, int b);

  #endif // ADDER_H
C

RECOVERY_ADDER_C = <<~C
  #include "adder.h"
  #include "sensor.h"

  // Defined in helper_impl.c, which only TEST_SOURCE_FILE() brings into the test build
  int helper_offset(void);

  int adder_add(int a, int b)
  {
      return a + b + sensor_bias() + helper_offset();
  }
C

RECOVERY_SENSOR_H = <<~C
  #ifndef SENSOR_H
  #define SENSOR_H

  int sensor_bias(void);

  #endif // SENSOR_H
C

RECOVERY_HELPER_IMPL_C = <<~C
  int helper_offset(void)
  {
      return 0;
  }
C

RECOVERY_TEST_ADDER_C = <<~C
  #include "unity.h"
  #include "adder.h"
  #include "mock_sensor.h"

  TEST_SOURCE_FILE("helper_impl.c")

  void setUp(void) {}
  void tearDown(void) {}

  void test_adds_with_bias(void)
  {
      sensor_bias_ExpectAndReturn(1);
      TEST_ASSERT_EQUAL_INT(6, adder_add(2, 3));
  }

  void test_adds_without_bias(void)
  {
      sensor_bias_ExpectAndReturn(0);
      TEST_ASSERT_EQUAL_INT(5, adder_add(2, 3));
  }
C

# Stands in for gcc. On the compile numbered in stall/at it marks the build as in flight
# and stalls, so a spec can interrupt the build at a known point. Otherwise it is gcc.
RECOVERY_STALLING_COMPILER_SH = <<~SH
  #!/bin/sh
  if [ -f stall/at ]; then
    count=$(( $(cat stall/count 2>/dev/null || echo 0) + 1 ))
    echo "$count" > stall/count
    if [ "$count" -eq "$(cat stall/at)" ]; then
      touch stall/stalled
      sleep 300
    fi
  fi
  exec gcc "$@"
SH

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "build_recovery"

  describe "Deployed as a gem" do

    before do
      in_project do
        File.write('src/adder.h', RECOVERY_ADDER_H)
        File.write('src/adder.c', RECOVERY_ADDER_C)
        File.write('src/sensor.h', RECOVERY_SENSOR_H)
        File.write('src/helper_impl.c', RECOVERY_HELPER_IMPL_C)
        File.write('test/test_adder.c', RECOVERY_TEST_ADDER_C)

        # Issue #1240's own configuration: everything preprocessed, crashes backtraced
        @c.merge_project_yml_for_test({
          :project => { :use_mocks => true, :use_test_preprocessor => :all, :use_backtrace => :simple }
        })
      end
    end

    def expect_green_build
      output = @c.ceedling_build_exec("test:all")

      expect(@c.last_exit_status).to eq(0), output.to_s
      expect(output).to match(/TESTED:\s+2/)
      expect(output).to match(/PASSED:\s+2/)
    end

    # The one artifact matching `pattern`, so a damage step never silently hits nothing
    def only_file(pattern)
      matches = Dir.glob(pattern)
      expect(matches.length).to eq(1), "expected one match for #{pattern}, found #{matches}"
      matches.first
    end

    # =========================================================================
    describe "a damaged build artifact" do
    # =========================================================================

      def damage_then_rebuild
        in_project do
          expect_green_build
          yield
          expect_green_build
        end
      end

      it "reruns a test whose cached result was truncated" do
        damage_then_rebuild do
          result = only_file('build/test/results/**/test_adder.pass')
          File.truncate(result, File.size(result) / 2)
        end
      end

      it "reruns a test whose cached result was emptied" do
        damage_then_rebuild do
          File.truncate(only_file('build/test/results/**/test_adder.pass'), 0)
        end
      end

      it "recompiles an object whose dependency file names a directory" do
        damage_then_rebuild do
          deps   = only_file('build/test/dependencies/**/adder.d')
          target = File.read(deps)[/\A(.*?):(?=\s)/, 1]
          File.write(deps, "#{target}: build/vendor/unity/src/\n")
        end
      end

      it "rebuilds a test's build directives when their cache directory was deleted" do
        damage_then_rebuild do
          FileUtils.rm_rf(Dir.glob('build/test/preprocess/build_directives/*/'))
        end
      end

      # An emptied cache loads as no directives at all, silently dropping helper_impl.c from
      # the object list. Nothing shows until a code change forces a relink, so this changes
      # adder.c's code too. Treating the cache as damaged rebuilds the directives instead.
      it "rebuilds a test's build directives when their cache was emptied" do
        damage_then_rebuild do
          File.truncate(only_file('build/test/preprocess/build_directives/**/*_source_files.yml'), 0)
          File.write('src/adder.c', RECOVERY_ADDER_C.sub('return a + b', "int sum = a + b;\n    return sum"))
        end
      end

      it "regenerates a mock whose generated header was truncated" do
        damage_then_rebuild do
          header = only_file('build/test/mocks/**/mock_sensor.h')
          File.truncate(header, File.size(header) / 2)
        end
      end
    end

    # =========================================================================
    describe "a broken project, then repaired" do
    # =========================================================================

      # Exit status plus test counts, the outcome a build is judged by
      def outcome(output)
        counts = %w[TESTED PASSED FAILED].map { |label| output.to_s[/^#{label}:\s+(\d+)/, 1] }
        [@c.last_exit_status] + counts
      end

      # Builds a passing project, breaks it, then builds twice more expecting the same
      # failing outcome both times. A failure that alternates between runs is its own bug.
      # `never` names output neither failing build may contain. Restoring the originals
      # must then build green twice over.
      def break_then_repair(failure:, never: nil)
        in_project do
          expect_green_build
          originals = Dir.glob('{src,test}/*').select { |path| File.file?(path) }.to_h { |path| [path, File.read(path)] }

          yield

          first  = @c.ceedling_build_exec("test:all")
          second = @c.ceedling_build_exec("test:all")

          expect(outcome(first).first).to_not eq(0), first.to_s
          expect(outcome(second)).to eq(outcome(first))
          expect(second).to match(failure)
          [first, second].each { |output| expect(output).to_not match(never) } if never

          originals.each { |path, content| File.write(path, content) }

          expect_green_build
          expect_green_build
        end
      end

      it "fails the same way on each build of a source compile error, and recovers once fixed" do
        break_then_repair(failure: /Test Compiler/) do
          File.write('src/adder.c', RECOVERY_ADDER_C + "\nthis is not C;\n")
        end
      end

      # The include resolves nowhere, which once sent preprocessing on to read output that
      # was never written (issue #1240). It must fail by naming the header instead.
      it "fails by naming a missing header on each build, and recovers once fixed" do
        break_then_repair(failure: /no_such_header\.h/, never: /comment stripping/) do
          File.write('test/test_adder.c', %(#include "no_such_header.h"\n) + RECOVERY_TEST_ADDER_C)
        end
      end

      it "fails the same way on each build of a link error, and recovers once fixed" do
        break_then_repair(failure: /Test Linker/) do
          File.write('test/test_adder.c', RECOVERY_TEST_ADDER_C + <<~C)

            int undefined_function(void);
            void test_links(void) { TEST_ASSERT_EQUAL_INT(0, undefined_function()); }
          C
        end
      end

      # Issue #1240's report: a crashing test, backtraced, alternated between results on
      # successive builds. Every build must report the same crash.
      it "reports a crashing test identically on each build, and recovers once fixed" do
        break_then_repair(failure: /crashed/i) do
          File.write('test/test_adder.c', RECOVERY_TEST_ADDER_C + <<~C)

            void test_crashes(void) { volatile int *p = 0; *p = 1; }
          C
        end
      end
    end

    # =========================================================================
    describe "an interrupted build" do
    # =========================================================================

      # Signals reach the build through its process group, and the stand-in compiler is a
      # shell script, so these cases need a POSIX host
      before do
        skip "Interrupting a build in flight is only exercised on POSIX hosts" if /mingw|win32/.match?(RUBY_PLATFORM.downcase)

        in_project do
          File.write('stall_cc.sh', RECOVERY_STALLING_COMPILER_SH)
          FileUtils.chmod(0755, 'stall_cc.sh')
          FileUtils.mkdir_p('stall')

          # One compile at a time, so "the Nth compile" names the same object every run
          @c.merge_project_yml_for_test({
            :project             => { :compile_threads => 1, :test_threads => 1 },
            :tools_test_compiler => { :executable => File.expand_path('stall_cc.sh') }
          })
        end
      end

      # Starts a build that stalls inside its Nth compile, signals the whole build while it
      # is stalled there, and expects the interrupted build to report failure
      def interrupt_build_at(compile:, signal:)
        File.write('stall/at', compile.to_s)
        FileUtils.rm_f(['stall/count', 'stall/stalled'])

        pid = Process.spawn('bundle exec ruby -S ceedling build test:all', pgroup: true, out: File::NULL, err: File::NULL)

        deadline = Time.now + 120
        until File.exist?('stall/stalled')
          raise "build finished before reaching compile #{compile}" if Process.waitpid(pid, Process::WNOHANG)
          raise "build never reached compile #{compile}" if Time.now > deadline
          sleep 0.1
        end

        Process.kill(signal, -pid)
        Process.wait(pid)

        # A signal-killed process reports neither success nor failure, only not success
        expect($?.success?).to be_falsey
      ensure
        FileUtils.rm_f('stall/at')
      end

      it "recovers from SIGKILL during the first compile of a clean build" do
        in_project do
          interrupt_build_at(compile: 1, signal: 'KILL')

          expect_green_build
          expect_green_build
        end
      end

      it "recovers from SIGINT partway through a clean build" do
        in_project do
          interrupt_build_at(compile: 3, signal: 'INT')

          expect_green_build
          expect_green_build
        end
      end

      # The rebuild compiles only the changed source, so its first compile is that source
      it "recovers from SIGKILL while recompiling a changed source" do
        in_project do
          expect_green_build
          File.write('src/adder.c', RECOVERY_ADDER_C.sub('return a + b', "int sum = a + b;\n    return sum"))

          interrupt_build_at(compile: 1, signal: 'KILL')

          expect_green_build
          expect_green_build
        end
      end
    end

  end
end
