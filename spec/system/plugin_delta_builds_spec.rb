# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/gcov_helpers'
require_relative 'support/valgrind_helpers'

# Gcov/Valgrind/Bullseye all run their own build through the exact same core test
# pipeline as ordinary `test:` builds, tagged with their own `context:` symbol --
# see spec/system/delta_builds_spec.rb for the equivalent ordinary-:test coverage
# this file extends to those plugin contexts specifically. Two gaps closed here:
#
# 1. Each pipeline context now gets its own isolated dependency cache file, so a
#    `test:all` run's own pruning flush no longer evicts a plugin context's cache.
# 2. A plugin's own swapped-in tool (Gcov's instrumented compiler, Valgrind's
#    executable wrapper) is resolved before dependency-tracker meta is captured,
#    so editing that plugin's own tool config actually invalidates its own cache.
ceedling_system_tests do
  include GcovHelpers

  before :all do
    determine_reports_to_test
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("plugin_delta") }

  def deploy_gcov_project!
    @c.ceedling_appcmd_exec("new --local #{@proj_name}")

    Dir.chdir @proj_name do
      prep_project_yml_for_coverage
      FileUtils.cp test_asset_path("example_file.h"), 'src/'
      FileUtils.cp test_asset_path("example_file.c"), 'src/'
      FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
    end
  end

  describe "Gcov context: cache isolation and tool-change staleness" do
    before do
      @c.with_context { deploy_gcov_project! }
    end

    it "does not evict the gcov context's cache when an ordinary test:all run happens in between" do
      @c.with_context do
        Dir.chdir @proj_name do
          baseline = @c.ceedling_build_exec("gcov:all")
          expect(baseline).to_not match(/EXCEPTION/)

          # An ordinary test:all run, sharing nothing on purpose with the gcov
          # context's own build tree -- before Gap 1, its refresh_dependencies
          # prune silently evicted gcov's cache entries anyway, since they lived
          # in the same shared cache file.
          @c.ceedling_build_exec("test:all")

          rebuild = @c.ceedling_build_exec("gcov:all")
          expect(rebuild).to_not match(/EXCEPTION/)
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
        end
      end
    end

    it "recompiles and relinks the gcov context when :tools ↳ :gcov_compiler changes, with no source edits" do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.ceedling_build_exec("gcov:all")

          # :gcov_compiler exists only via the plugin's own defaults, never in a
          # project's own project.yml -- merging just an inert key into it here
          # (as the equivalent :tools ↳ :test_compiler scenario in
          # delta_builds_spec.rb does) triggers an unrelated, pre-existing
          # frozen-string crash when Ceedling merges a project-supplied partial
          # override on top of a plugin-default-only tool entry's frozen
          # :arguments (present identically on next_version before this branch,
          # confirmed via a clean worktree at that commit). Supplying the whole
          # tool -- matching plugins/gcov/config/defaults_gcov.rb's
          # DEFAULT_GCOV_COMPILER_TOOL, plus the inert key -- sidesteps that
          # unrelated bug rather than working around it here; the actual
          # dependency-tracker-meta assertion this test cares about is unaffected
          # either way.
          @c.merge_project_yml_for_test({
            :tools => {
              :gcov_compiler => {
                :executable => 'gcc',
                :name       => 'default_gcov_compiler',
                :optional   => false,
                :arguments  => [
                  '-g', '-fprofile-arcs', '-ftest-coverage',
                  '-I"${5}"', '-D"${6}"', '-DGCOV_COMPILER', '-DCODE_COVERAGE',
                  '-c "${1}"', '-o "${2}"', '-MMD', '-MF "${4}"'
                ],
                :ceedling_delta_probe => true
              }
            }
          })

          rebuild = @c.ceedling_build_exec("gcov:all")
          expect(rebuild).to_not match(/EXCEPTION/)
          expect(rebuild).to match(/^Compiling /)
        end
      end
    end

    it "prints the coverage summary on a fully-cached gcov:all re-run" do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.ceedling_build_exec("gcov:all")

          rebuild = @c.ceedling_build_exec("gcov:all")
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to match(/GCOV: CODE COVERAGE SUMMARY/i).or match(/Coverage Summary/i)
        end
      end
    end
  end

  describe "Valgrind context: cache isolation and tool-change staleness" do
    include_context "requires valgrind"

    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new --local #{@proj_name}")

        Dir.chdir @proj_name do
          FileUtils.cp feature_asset_path("project.yml"), "project.yml"
          @c.uncomment_project_yml_option_for_test("- valgrind")
          FileUtils.cp test_asset_path("example_file.h"), 'src/'
          FileUtils.cp test_asset_path("example_file.c"), 'src/'
          FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        end
      end
    end

    it "does not evict the valgrind context's cache when an ordinary test:all run happens in between" do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.ceedling_build_exec("valgrind:all")
          @c.ceedling_build_exec("test:all")

          rebuild = @c.ceedling_build_exec("valgrind:all")
          expect(rebuild).to_not match(/EXCEPTION/)
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to_not match(/^Running /)
        end
      end
    end

    it "reruns the valgrind context's fixture when :valgrind ↳ :arguments changes, with nothing else changed" do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.ceedling_build_exec("valgrind:all")

          @c.merge_project_yml_for_test({ :valgrind => { :arguments => ["--leak-check=full", "--show-leak-kinds=all", "--track-origins=yes", "--errors-for-leak-kinds=all", "--num-callers=40"] } })

          rebuild = @c.ceedling_build_exec("valgrind:all")
          expect(rebuild).to_not match(/EXCEPTION/)
          expect(rebuild).to_not match(/^Compiling /)
          expect(rebuild).to_not match(/^Linking /)
          expect(rebuild).to match(/^Running /)
        end
      end
    end
  end
end
