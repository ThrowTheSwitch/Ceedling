# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Multiple Filename Extensions Per File Type
## ===========================================
##
## A project may name a single file type -- assembly, in this case -- with more
## than one extension at once (e.g. both `.s` and `.S`, as GitHub issue #947
## describes for projects like ThreadX). These tests confirm that when
## :extension -> :assembly is configured as a list, Ceedling finds, compiles,
## and links files under every extension in that list within the same project,
## not just whichever extension happens to be listed first.
##
## Test assets: assets/fixtures/tests_with_multiple_assembly_extensions/
##   - counter_module.c/.h: an ordinary C module with one function
##   - asm_helper_lower.s / asm_helper_upper.S: two assembly files, deliberately
##     empty of real instructions (portable across architectures), one under
##     each of the two configured extensions
##   - test_counter_module.c: exercises the C module only; the assembly files'
##     role here is purely to prove the build discovers and compiles both
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("multi_ext_asm") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end


    # =========================================================================
    describe "A project configured with a list of assembly extensions" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_multiple_assembly_extensions/src/counter_module.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_multiple_assembly_extensions/src/counter_module.c"), 'src/'
            FileUtils.cp test_asset_path("tests_with_multiple_assembly_extensions/src/asm_helper_lower.s"), 'src/'
            FileUtils.cp test_asset_path("tests_with_multiple_assembly_extensions/src/asm_helper_upper.S"), 'src/'
            FileUtils.cp test_asset_path("tests_with_multiple_assembly_extensions/test/test_counter_module.c"), 'test/'
          end
        end
      end

      it "discovers, reports, and compiles assembly files under every configured extension" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = {
              :extension  => { :assembly => ['.s', '.S'] },
              :test_build => { :use_assembly => true }
            }
            @c.merge_project_yml_for_test(settings)

            files_output = @c.ceedling_build_exec("files:assembly")
            expect(files_output).to match(/asm_helper_lower\.s/)
            expect(files_output).to match(/asm_helper_upper\.S/)

            build_output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(build_output).to match(/Assembling.*asm_helper_lower\.s/)
            expect(build_output).to match(/Assembling.*asm_helper_upper\.S/)
            expect(build_output).to match(/TESTED:\s+1/)
            expect(build_output).to match(/PASSED:\s+1/)
            expect(build_output).to match(/FAILED:\s+0/)
          end
        end
      end

    end

  end

end
