# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## End-to-end builds for one test exercising two modules that share a basename.
##
## Ceedling's own convention correlates an #include'd header with the source beside
## it, so a test naming two same-basename headers by different paths compiles and
## links both modules. Full path resolution is what keeps the two apart.
##
## Both config modules compute through a private `adjust` defined with different
## arithmetic, so a collapsed resolution still compiles and links. It surfaces as a
## wrong value rather than a missing symbol, which is the silent failure to guard
## against.
##
## Preprocessing is the variable here. It routes each source through a generated
## intermediate file, and that is where two same-basename sources in one test can
## collide, so each setting gets its own example.
##
## Mocking both modules in one test is the second subject. Each mock must be
## named by the directory its #include names or the two mocks collide.
##
## Assets: assets/fixtures/same_named_modules/
##

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "same_named"

  describe "Deployed as a gem" do

    context "with two same-named modules in one test" do
      def stage(preprocess)
        copy_same_named_modules('uart', 'spi', preprocess: preprocess)
        in_project do
          copy_fixture("same_named_modules/test/test_both_modules.c", 'test')
        end
      end

      def expect_green
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      it "compiles and links both modules with preprocessing disabled" do
        stage(:none)
        expect_green
      end

      it "compiles and links both modules with tests preprocessed" do
        stage(:tests)
        expect_green
      end

      # The broadest setting, which preprocesses the module sources themselves. Two
      # same-basename sources under one test each need their own intermediate file.
      it "compiles and links both modules with all files preprocessed" do
        stage(:all)
        expect_green
      end

      # Objects mirror their source's own subdirectory, so same-named sources never
      # overwrite one another's object.
      it "builds each module into its own mirrored object" do
        stage(:all)
        in_project do
          @c.ceedling_build_exec("test:all")

          objects = Dir.glob('build/test/out/**/config.o')

          expect(objects.length).to eq(2)
          expect(objects.any? { |path| path.include?('drivers/uart') }).to be true
          expect(objects.any? { |path| path.include?('drivers/spi') }).to be true
        end
      end
    end

    # Mocking is the other half of naming two same-named modules in one test. Each
    # needs its own mock, held apart by the directory its #include names.
    context "with both same-named modules mocked in one test" do
      before do
        copy_same_named_modules('uart', 'spi')
        in_project do
          copy_fixture("same_named_modules/test/test_both_configs_mocked_traditional.c", 'test')
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
    end

  end
end
