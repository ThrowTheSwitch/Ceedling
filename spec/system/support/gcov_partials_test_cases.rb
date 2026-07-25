# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rexml/document'
require_relative 'gcov_helpers'

module GcovPartialsTestCases
  include GcovHelpers

  # Runs `ceedling gcov:all` with Partials + Cobertura XML reporting enabled, then
  # returns { line_number => hits } for `source_relpath` (e.g. 'src/blanks.c').
  def partials_cobertura_hits_by_line(source_relpath)
    @c.merge_project_yml_for_test({
      :project => { :use_partials => true },
      :gcov    => { :reports => ['Cobertura'] }
    })

    output = @c.ceedling_build_exec("gcov:all")
    expect(@c.last_exit_status).to eq(0)

    cobertura_path = File.join('build', 'artifacts', 'gcov', 'gcovr', 'GcovCoverageCobertura.xml')
    doc = REXML::Document.new(File.read(cobertura_path))

    doc.elements.to_a("//class[@filename='#{source_relpath}']/lines/line").each_with_object({}) do |el, h|
      h[el.attributes['number'].to_i] = el.attributes['hits'].to_i
    end
  end

  def gcov_partials_coverage_blank_lines_in_function_body
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage

        # Multiple consecutive blank lines inside a function body -- the same
        # shape a stripped multi-line comment leaves behind -- sit between the
        # opening brace and the one executed statement. Each function in a
        # generated Partial gets exactly one #line directive, at its own first
        # line; every line after that is trusted to match the original source
        # 1:1. If any lines partway through the body go missing during
        # reconstruction, gcov's line attribution for everything after that
        # point in the function shifts up by the deficit.
        asset_base = test_asset_path("tests_with_partials_coverage")
        FileUtils.cp "#{asset_base}/src/blanks.h",       'src/'
        FileUtils.cp "#{asset_base}/src/blanks.c",       'src/'
        FileUtils.cp "#{asset_base}/test/test_blanks.c", 'test/'

        hits = partials_cobertura_hits_by_line('src/blanks.c')

        # `return;` is on source line 5 -- it must show as hit.
        expect(hits[5]).to be > 0
        # The blank lines (3-4) must not appear as executable/hit lines at all.
        expect(hits[3]).to be_nil
        expect(hits[4]).to be_nil
      end
    end
  end

  def gcov_partials_coverage_decorators_on_own_lines
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage

        # `static` and `inline` each occupy their own line ahead of the return
        # type. Partials strips both keywords from the front of the extracted
        # function text (per the docs, functions are stripped of `static` and
        # `inline`) and must bump the emitted #line directive forward by
        # exactly the number of lines that stripping removed -- otherwise the
        # whole body, including the blank line below, reports coverage against
        # the wrong original source lines.
        asset_base = test_asset_path("tests_with_partials_coverage")
        FileUtils.cp "#{asset_base}/src/decorators.h",       'src/'
        FileUtils.cp "#{asset_base}/src/decorators.c",       'src/'
        FileUtils.cp "#{asset_base}/test/test_decorators.c", 'test/'

        hits = partials_cobertura_hits_by_line('src/decorators.c')

        # `return;` is on source line 7 -- it must show as hit.
        expect(hits[7]).to be > 0
        # The blank line (6) must not appear as an executable/hit line.
        expect(hits[6]).to be_nil
      end
    end
  end

  def gcov_partials_coverage_function_scope_static_promotion
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage

        # A function-scope `static` variable is replaced with a no-op and
        # promoted to module scope so the Partial's testable copy of the
        # function keeps the original's persistence semantics (per the docs'
        # Partials creation steps). Confirms that substitution doesn't shift
        # the lines after it out of alignment with their original source line
        # numbers.
        asset_base = test_asset_path("tests_with_partials_coverage")
        FileUtils.cp "#{asset_base}/src/counter.h",       'src/'
        FileUtils.cp "#{asset_base}/src/counter.c",       'src/'
        FileUtils.cp "#{asset_base}/test/test_counter.c", 'test/'

        hits = partials_cobertura_hits_by_line('src/counter.c')

        # `count++;` (line 5) and `return count;` (line 7) must both show as
        # hit, correctly separated by the blank lines around them (4 and 6).
        expect(hits[5]).to be > 0
        expect(hits[7]).to be > 0
        expect(hits[4]).to be_nil
        expect(hits[6]).to be_nil
      end
    end
  end
end
