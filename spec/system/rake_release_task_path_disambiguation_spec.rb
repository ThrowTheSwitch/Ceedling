# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Rake Release Task Path Disambiguation
## =======================================
##
## The ad hoc `release:compile:<file>` task (lib/ceedling/rakefiles/release/rules_release.rake) hands
## its file argument straight to FileFinder without ever reducing it to a bare
## basename first, so it inherits path disambiguation for free from the same
## PathMatcher every other lookup in the project uses -- no rule-specific handling
## of its own was needed. These tests confirm that inheritance actually holds: a
## project with two same-named release sources in different source directories
## (e.g. src/foo/bar.c and src/baz/bar.c), `release:compile:bar.c` invoked by bare
## basename resolves to the first candidate by :paths search-path order (src/baz/bar.c,
## since "baz" sorts ahead of "foo" within :source's single src/** glob), logging an
## ℹ️ NOTICE naming src/foo/bar.c as passed over, while `release:compile:foo/bar.c` or
## `release:compile:baz/bar.c` (enough trailing path to identify one of them) compiles
## exactly that one source to its own correctly mirrored object, logging nothing.
##
## `release:assemble:<file>` resolves through the identical FileFinder/PathMatcher
## path (find_assembly_file rather than find_source_file), so it is not separately
## exercised here.
##
## Test assets: assets/fixtures/sources_with_duplicate_basenames/
##   - foo/bar.c, foo/bar.h: defines foo_bar_value() returning 111
##   - baz/bar.c, baz/bar.h: defines baz_bar_value() returning 222
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dup_release_source_name") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")

        Dir.chdir @proj_name do
          @c.merge_project_yml_for_test({ :project => { :release_build => true } })

          FileUtils.mkdir_p 'src/foo'
          FileUtils.mkdir_p 'src/baz'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/foo/bar.c"), 'src/foo/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/foo/bar.h"), 'src/foo/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/baz/bar.c"), 'src/baz/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/baz/bar.h"), 'src/baz/'
        end
      end
    end

    # =========================================================================
    describe "A project with two same-named release sources in different source directories" do
    # =========================================================================

      it "resolves to the first candidate by search-path order when release:compile: is invoked by bare basename, logging a NOTICE naming the other" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("release:compile:bar.c")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/Multiple files matched/)
            expect(output).to match(/foo[\/\\]bar\.c/)
            expect(output).to match(/baz[\/\\]bar\.c/)
            expect(output).to match(/^Compiling bar\.c/)

            expect(File.exist?('build/release/out/baz/bar.o')).to be true
            expect(File.exist?('build/release/out/foo/bar.o')).to be false
          end
        end
      end

      it "compiles exactly the foo module when disambiguated by path" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("release:compile:foo/bar.c")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/^Compiling bar\.c/)
            expect(output).to_not match(/^Linking /)

            expect(File.exist?('build/release/out/foo/bar.o')).to be true
            expect(File.exist?('build/release/out/baz/bar.o')).to be false
          end
        end
      end

      it "compiles exactly the baz module when disambiguated by path" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("release:compile:baz/bar.c")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/^Compiling bar\.c/)
            expect(output).to_not match(/^Linking /)

            expect(File.exist?('build/release/out/baz/bar.o')).to be true
            expect(File.exist?('build/release/out/foo/bar.o')).to be false
          end
        end
      end

    end

  end

end
