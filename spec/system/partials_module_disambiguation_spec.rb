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
## Assets: assets/fixtures/partials_same_named_modules/
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
          copy_fixture("partials_same_named_modules/test/test_uart_config_bare.c", 'test')
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

  end
end
