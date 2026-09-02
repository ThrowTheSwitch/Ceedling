# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## A Source Path Segment Containing Literal [] Brackets Is Not Dropped (issue #104)
## ==================================================================================
##
## `[`/`]` are legal filename characters (Windows especially -- the original report's
## own scenario) but Ruby's Dir.glob treats an unescaped `[...]` as character-class
## glob syntax, so a literal bracket in a real directory name silently failed to match
## its own glob pattern. This broke not just plugin :load_paths: detection (the
## original 2016 report) but the whole :paths: family: a source subdirectory named
## e.g. `[legacy]` was silently dropped from the build entirely -- Dir.glob('src/**')
## simply never matched it, no error, the file just never got compiled.
##

EXAMPLE_HEADER_BRACKET_PATH = <<~C
  #ifndef EXAMPLE_FILE_BRACKET_H
  #define EXAMPLE_FILE_BRACKET_H

  int example_file_bracket_add(int a, int b);

  #endif
C

EXAMPLE_SOURCE_BRACKET_PATH = <<~C
  #include "example_file_bracket.h"

  int example_file_bracket_add(int a, int b)
  {
    return a + b;
  }
C

TEST_BRACKET_PATH_C = <<~C
  #include "unity.h"
  #include "example_file_bracket.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_source_under_a_bracket_named_directory_is_compiled(void)
  {
    TEST_ASSERT_EQUAL_INT(3, example_file_bracket_add(1, 2));
  }
C

# A trivial, dependency-free test -- these two additional scenarios exercise
# collection/lookup paths (test-file collection, vendor framework collection, test
# runner lookup) unrelated to source/header collection, so they don't need the
# example_file_bracket fixtures above.
TRIVIAL_TEST_C = <<~C
  #include "unity.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_trivial_truth(void)
  {
    TEST_ASSERT_EQUAL_INT(1, 1);
  }
C

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("bracket_path") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    before do
      @c.with_context do
        Dir.chdir @proj_name do
          # The default :paths: ↳ :source/:include is `src/**` -- already recursive,
          # so a bracket-named subdirectory needs no extra :paths: config to exercise
          # the bug; it's dropped (or, pre-fix validation, hard-errored) purely by
          # virtue of Dir.glob never matching '[legacy]' as a literal directory name.
          FileUtils.mkdir_p('src/[legacy]')
          File.write('src/[legacy]/example_file_bracket.h', EXAMPLE_HEADER_BRACKET_PATH)
          File.write('src/[legacy]/example_file_bracket.c', EXAMPLE_SOURCE_BRACKET_PATH)
          File.write('test/test_bracket_path.c', TEST_BRACKET_PATH_C)
        end
      end
    end

    it "compiles and tests a source file living under a bracket-named directory" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to_not match(/yielded no directories/)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end
  end

  ##
  ## A Test File Itself Living Under a Bracket-Named Directory Is Not Dropped
  ## ==========================================================================
  ##
  ## The default :paths: ↳ :test convention (`+:test/**`) is just as recursive as
  ## :source/:include, and test-file collection (ConfiguratorBuilder#collect_tests)
  ## builds its own glob pattern independently of source/header collection -- a
  ## separate call site that needed its own fix. This also exercises test runner
  ## lookup (FileFinder#runner_scope_dir), since the runner generated for a test
  ## under a bracket-named directory is itself mirrored into a bracket-named
  ## subdirectory of the runners output path and must be found again there.
  ##

  describe "Deployed as a gem, test file under a bracket-named directory" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    before do
      @c.with_context do
        Dir.chdir @proj_name do
          FileUtils.mkdir_p('test/[legacy]')
          File.write('test/[legacy]/test_trivial.c', TRIVIAL_TEST_C)
        end
      end
    end

    it "compiles and tests a test file living under a bracket-named directory" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to_not match(/yielded no directories/)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end
  end

  ##
  ## A Project Whose (Absolute) Build Root Falls Under a Bracket-Named Directory
  ## Is Not Dropped
  ## ==========================================================================
  ##
  ## The original 2016 report's own scenario (a bracket-containing staging/temp
  ## directory, common on Windows). Every vendor framework path (Unity, and
  ## CException/CMock when enabled) is rooted at :project ↳ :build_root -- `build`
  ## by default, which is *relative* and so never embeds the project's own
  ## directory ancestry in a glob pattern at all (Dir.glob resolves a relative
  ## pattern against the process's cwd without re-parsing the cwd itself as glob
  ## syntax). Only an *absolute* :build_root: -- a legitimate, supported setting --
  ## actually embeds a bracket-containing ancestor into the glob pattern text these
  ## vendor-collection call sites build, so that's what this scenario configures.
  ##

  describe "Deployed as a gem, absolute build root under a bracket-named directory" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    before do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('test/test_trivial.c', TRIVIAL_TEST_C)

          # Absolute :build_root: under a bracket-named directory -- forces every
          # vendor framework path (derived from :build_root:) to carry the bracket
          # literally in the glob pattern text, unlike the default relative 'build'.
          bracket_build_root = File.expand_path( File.join('[build-staging]', 'build') )
          @c.merge_project_yml_for_test({ :project => { :build_root => bracket_build_root } })
        end
      end
    end

    it "compiles and tests a project whose absolute build root falls under a bracket-named directory" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to_not match(/yielded no directories/)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end
  end

end
