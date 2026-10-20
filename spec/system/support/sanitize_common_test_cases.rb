# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require_relative 'sanitize_helpers'

module SanitizeCommonTestCases
  include SanitizeHelpers

  def project_build_tasks_plugins_help_for_sanitize
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        output = @c.ceedling_appcmd_exec("help")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/ceedling sanitize:\*/i)
        expect(output).to match(/ceedling sanitize:all/i)
      end
    end
  end

  def run_sanitize_on_clean_tests
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        prep_sanitize_sources("test_example_file_success.c")

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/SANITIZE: .*OVERALL TEST SUMMARY/)
        expect(output).not_to match(/Sanitizers found/)
        expect(Dir.glob('build/artifacts/sanitize/sanitize/*.log')).to be_empty
      end
    end
  end

  # The plugin builds in its own context, apart from test builds
  def run_sanitize_build_removed_by_clobber
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        prep_sanitize_sources("test_example_file_success.c")

        @c.ceedling_build_exec("sanitize:all")
        expect(Dir.glob('build/sanitize/**/*').select { |path| File.file?( path ) }).not_to be_empty

        @c.ceedling_build_exec("clobber")
        expect(@c.last_exit_status).to eq(0)
        expect(Dir.glob('build/sanitize/**/*').select { |path| File.file?( path ) }).to be_empty
        expect(Dir.glob('build/artifacts/sanitize/**/*').select { |path| File.file?( path ) }).to be_empty
        expect(Dir.glob('build/cache/.*.dep_cache.json')).to be_empty
      end
    end
  end

  # A halt is a crash, named by its finding, with the sanitizer's report kept in a log
  def run_sanitize_names_an_asan_finding
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        prep_sanitize_sources("test_nosanitize_heap_buffer_overflow.c")

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/test_writes_past_its_buffer.*\n.*AddressSanitizer heap-buffer-overflow at \S*test_nosanitize_heap_buffer_overflow\.c:\d+/)
        expect(output).to match(/Sanitizers found 1 problem in 1 test/)
        expect(read_spec_file('build/artifacts/sanitize/sanitize/test_nosanitize_heap_buffer_overflow.log')).to match(/ERROR: AddressSanitizer: heap-buffer-overflow/)
      end
    end
  end

  def run_sanitize_names_a_ubsan_finding
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        FileUtils.cp test_asset_path("test_nosanitize_ub_shift_overflow.c"), 'test/'

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/test_shift_overflow.*\n.*UndefinedBehaviorSanitizer left shift of 128 by 24 places/)
      end
    end
  end

  # A crash no sanitizer reported keeps its own message, with no finding made up for it
  # The first finding halts the main run, so only the second test case's backtrace rerun
  # reaches the second finding. Both are counted and reported.
  def run_sanitize_counts_a_finding_only_a_rerun_reaches
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        @c.merge_project_yml_for_test({ :sanitize => { :reports => [:sarif] } })
        FileUtils.cp test_asset_path("test_nosanitize_two_findings.c"), 'test/'

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/AddressSanitizer heap-buffer-overflow at /)
        expect(output).to match(/UndefinedBehaviorSanitizer .* at /)
        expect(output).to match(%r{Sanitizers found 2 problems in 1 test\. See the reports in build/artifacts/sanitize/sanitize: sanitize\.sarif\.})

        sarif = JSON.parse(read_spec_file('build/artifacts/sanitize/sanitize/sanitize.sarif'))
        expect(sarif['runs'].first['results'].map { |result| result['ruleId'] }).to contain_exactly(
          'address/heap-buffer-overflow', 'undefined/undefined-behavior'
        )
      end
    end
  end

  def run_sanitize_leaves_a_plain_crash_alone
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        prep_sanitize_sources("test_nosanitize_crash_assert.c")

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/Test case crashed/)
        expect(output).not_to match(/Sanitizers found/)
      end
    end
  end

  # A leak is found at exit, after every test case passed, so it is a finding, not a crash
  def run_sanitize_reports_a_leak_as_a_finding
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        prep_sanitize_sources("test_nosanitize_leak.c")

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).not_to match(/crashed/i)
        expect(output).to match(/PASSED:\s+2/)
        expect(output).to match(/test_nosanitize_leak: LeakSanitizer memory-leak at /)
        expect(output).to match(/Sanitizers found 1 problem in 1 test/)
      end
    end
  end

  def run_sanitize_leak_with_fail_build_disabled
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        @c.merge_project_yml_for_test({ :sanitize => { :fail_build => false } })
        prep_sanitize_sources("test_nosanitize_leak.c")

        output = @c.ceedling_build_exec("sanitize:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/test_nosanitize_leak: LeakSanitizer memory-leak at /)
        expect(output).not_to match(/Sanitizers found/)
      end
    end
  end

  def run_sanitize_writes_structured_reports
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        @c.merge_project_yml_for_test({ :sanitize => { :reports => [:json, :sarif] } })
        prep_sanitize_sources("test_nosanitize_heap_buffer_overflow.c")

        @c.ceedling_build_exec("sanitize:all")

        json = JSON.parse(read_spec_file('build/artifacts/sanitize/sanitize/sanitize.json'))
        expect(json['findings'].first).to include('sanitizer' => 'address', 'kind' => 'heap-buffer-overflow')

        sarif = JSON.parse(read_spec_file('build/artifacts/sanitize/sanitize/sanitize.sarif'))
        expect(sarif['runs'].first['results'].first['ruleId']).to eq('address/heap-buffer-overflow')
      end
    end
  end

  # :test_builds instruments ordinary test: builds as well
  def run_sanitize_instruments_test_builds_when_asked
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        @c.merge_project_yml_for_test({ :sanitize => { :test_builds => true } })
        prep_sanitize_sources("test_nosanitize_heap_buffer_overflow.c")

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/AddressSanitizer heap-buffer-overflow/)
      end
    end
  end

  # Ordinary test: builds are left alone by default
  def run_sanitize_leaves_test_builds_alone
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        prep_sanitize_sources("test_nosanitize_heap_buffer_overflow.c")

        output = @c.ceedling_build_exec("test:all")
        expect(output).not_to match(/Sanitizer/)
      end
    end
  end

  # A sanitizer-instrumented executable can't run under Valgrind
  def run_valgrind_refuses_sanitizer_flags
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_sanitize
        @c.uncomment_project_yml_option_for_test("- valgrind")
        @c.merge_project_yml_for_test({ :flags => { :test => { :compile => { :* => ['-fsanitize=address'] } } } })
        prep_sanitize_sources("test_example_file_success.c")

        output = @c.ceedling_build_exec("valgrind:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/Valgrind cannot run a test executable built with sanitizers/)
        expect(output).to match(/`-fsanitize=address`/)
      end
    end
  end

end
