# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Subdirectory-Qualified #include Preservation -- end-to-end smoke
## ================================================================
##
## The detail of how Ceedling reconciles a user #include's own subdirectory
## qualification -- a literal text-scan bare entry tagged with its own,
## `..`-resolved spelling; the bare-includes union merging (not merely
## deduplicating) by filepath so two headers that share only a basename both
## survive; Includes.reconcile recovering that tagged spelling for its matched
## user include -- is characterized directly against real GCC in
## spec/integration/includes_extraction_spec.rb. This spec keeps one full
## `ceedling` build proving the reconciled paths actually reach a generated
## Partial file and the result compiles and links: sensor.c #includes three
## headers that all share the basename config.h from three different
## directories (two ordinary subdirectories, one reached only via a
## `..`-relative directive) -- any two of the three colliding on a bare
## "config.h" in the generated file leaves at least one macro undeclared, a
## guaranteed compile error regardless of which file an ambiguous bare
## "config.h" happened to resolve to first. See sensor.c for the full shape.
##
## Assets: assets/fixtures/tests_with_subdir_includes/
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("subdir_inc") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
        Dir.chdir @proj_name do
          %w[
            module/sensor.h module/sensor.c
            module/drivers/config.h module/app/config.h
          ].each do |f|
            dest = File.join('src', File.dirname(f))
            FileUtils.mkdir_p(dest)
            FileUtils.cp test_asset_path("tests_with_subdir_includes/src/#{f}"), dest
          end
          FileUtils.mkdir_p('src/shared')
          FileUtils.cp test_asset_path("tests_with_subdir_includes/src/shared/config.h"), 'src/shared/'
          FileUtils.cp test_asset_path("tests_with_subdir_includes/test/test_sensor.c"), 'test/'

          @c.merge_project_yml_for_test(:project => { :use_partials => true })
        end
      end
    end

    it "reaches the generated Partial with each same-basename header's own disambiguating path" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec("test:sensor")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end
  end

end
