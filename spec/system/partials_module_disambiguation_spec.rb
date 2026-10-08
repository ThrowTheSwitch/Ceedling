# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## End-to-end builds for selecting a Partial module when more than one module
## shares its basename.
##
## The project shape is issue #1311's own: one include root, headers namespaced
## below it, and a source tree mirroring that namespace. Both config modules define
## a private `adjust` with different arithmetic, so a Partial built from the wrong
## module still compiles and links. A wrong resolution surfaces as a wrong value,
## which is the silent failure the issue warns about.
##
## Assets: assets/fixtures/same_named_modules/
##

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partial_disambig"

  describe "Deployed as a gem" do

    # One module staged, so its bare name is unambiguous project-wide. This is the
    # baseline the ambiguous cases are read against.
    context "with only one of the two same-named modules present" do
      before do
        copy_same_named_partial_modules('uart')
        in_project do
          copy_fixture("same_named_modules/test/test_uart_config_bare.c", 'test')
        end
      end

      it "builds a Partial from a bare module name and reaches that module's own functions" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end

    # Issue #1311's own shape: one test file Partializing two modules that share a
    # basename, each named by its own directory.
    context "with both same-named modules Partialized in one test" do
      before do
        copy_same_named_partial_modules('uart', 'spi')
        in_project do
          copy_fixture("same_named_modules/test/test_both_configs.c", 'test')
        end
      end

      it "builds a Partial per module and reaches each module's own functions" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      # Fallback preprocessing synthesizes each generated Partial's #include from the
      # module name rather than resolving the real file, so the include carries its
      # module's directory without sitting under any build root. That directory still
      # names the module, and dropping it leaves two same-named modules indistinguishable
      # even though the test named both by directory.
      it "builds a Partial per module under fallback preprocessing" do
        in_project do
          @c.merge_project_yml_for_test({ :test_build => { :preprocess_force_fallback => true } })

          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      # The two Partials are distinct files only because each sits in the subdirectory
      # mirroring its own module. Sharing one directory would mean sharing one filename.
      it "generates each Partial into its own mirrored subdirectory" do
        in_project do
          @c.ceedling_build_exec("test:all")

          partials = Dir.glob('build/test/partials/**/ceedling_partial_config_impl.c')

          expect(partials.length).to eq(2)
          expect(partials.any? { |path| path.include?('drivers/uart') }).to be true
          expect(partials.any? { |path| path.include?('drivers/spi') }).to be true
        end
      end
    end

    # Mocking is the other half of the same feature. Two same-named modules each mocked as
    # a Partial must each get their own mock, which only happens if the two are held apart
    # by the directory that distinguishes them.
    context "with both same-named modules mocked as Partials in one test" do
      before do
        copy_same_named_partial_modules('uart', 'spi')
        in_project do
          copy_fixture("same_named_modules/test/test_both_configs_mocked.c", 'test')
        end
      end

      # Both mocks share a filename, so only the directory each #include names tells them
      # apart. CMock and the runner fold that directory into each mock's guard and
      # lifecycle function names.
      it "generates a mock per module and keeps their expectations separate" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      it "generates each mock into its own mirrored subdirectory" do
        in_project do
          @c.ceedling_build_exec("test:all")

          mocks = Dir.glob('build/test/mocks/**/mock_ceedling_partial_config_interface.c')

          expect(mocks.length).to eq(2)
          expect(mocks.any? { |path| path.include?('drivers/uart') }).to be true
          expect(mocks.any? { |path| path.include?('drivers/spi') }).to be true
        end
      end
    end

  end
end
