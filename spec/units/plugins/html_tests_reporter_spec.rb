# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'

$: << File.expand_path('../../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'html_tests_reporter'

describe HtmlTestsReporter do
  let(:reporter) { described_class.new(handle: :html) }

  let(:results) do
    {
      successes: [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_a' } ] } ],
      failures:  [ { source: { file: 'test/TestFoo.c' },
                     collection: [ { test: 'test_b', line: 30, message: 'Expected 1 Was 2' } ] } ],
      ignores:   [ { source: { file: 'test/TestFoo.c' }, collection: [ { test: 'test_c' } ] } ],
      counts: { total: 3, passed: 1, failed: 1, ignored: 1 }
    }
  end

  # Real, computed geometry -- a good regression net for the whole file,
  # independent of the escaping/passed-count fixes for well-formed input.
  describe '#ring_chart_svg (private)' do
    it 'returns an empty string when there are no tests at all' do
      expect(reporter.send(:ring_chart_svg, 0, 0, 0)).to eq('')
    end

    it 'omits a zero-count segment and gives the sole segment the full circumference' do
      svg = reporter.send(:ring_chart_svg, 3, 0, 0)
      expect(svg.scan('<circle').length).to eq(1)
      expect(svg).to include('stroke="#27ae60"')

      circumference = 2 * Math::PI * 36
      expect(svg).to include("stroke-dasharray=\"#{circumference.round(3)} 0.0\"")
    end

    it 'splits the circumference proportionally across passed/failed/ignored segments' do
      svg = reporter.send(:ring_chart_svg, 1, 1, 1)
      expect(svg.scan('<circle').length).to eq(3)

      circumference = 2 * Math::PI * 36
      third = (circumference / 3.0).round(3)
      expect(svg.scan(/stroke-dasharray="([\d.]+) /).flatten.map(&:to_f)).to all(be_within(0.01).of(third))
    end
  end

  describe '#body' do
    it 'includes a table section for each of failures, ignores, and successes' do
      stream = StringIO.new
      reporter.body(stream: stream, name: 'Ceedling Test Suite', results: results, duration_s: 1.5)

      expect(stream.string).to include('table class="failed"')
      expect(stream.string).to include('table class="ignored"')
      expect(stream.string).to include('table class="success"')
      expect(stream.string).to include('test_a')
      expect(stream.string).to include('test_b')
      expect(stream.string).to include('test_c')
    end

    # --- Fix below this point: written to fail against pre-fix code ---

    it 'HTML-escapes a test name and failure message containing markup (fix: no escaping at all today)' do
      escaping_results = {
        successes: [], ignores: [],
        failures: [ { source: { file: 'test/TestFoo.c' },
                      collection: [ { test: '<script>evil()</script>', line: 30, message: 'a < b & c' } ] } ],
        counts: { total: 1, passed: 0, failed: 1, ignored: 0 }
      }
      stream = StringIO.new
      reporter.body(stream: stream, name: 'Ceedling Test Suite', results: escaping_results, duration_s: nil)

      expect(stream.string).not_to include('<script>evil()</script>')
      expect(stream.string).to include('&lt;script&gt;evil()&lt;/script&gt;')
      expect(stream.string).to include('a &lt; b &amp; c')
    end
  end

  describe '#write_summary (private) (fix: trusts counts[:passed] directly rather than recomputing it from :total)' do
    it 'shows the real aggregated passed count even when :total is stale/inconsistent' do
      stream = StringIO.new
      # :total is deliberately stale/wrong; :passed is the real, correct aggregate.
      reporter.send(:write_summary, 'x', { total: 999, passed: 2, failed: 1, ignored: 1 }, nil, stream)

      expect(stream.string).to match(%r{<td>Passed</td><td>2</td>})
    end
  end
end
