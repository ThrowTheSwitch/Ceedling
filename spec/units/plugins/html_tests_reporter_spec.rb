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

  # The chart is computed geometry, so its arcs are pinned numerically
  describe 'HtmlRingChart.svg' do
    it 'returns an empty string when there are no tests at all' do
      expect(HtmlRingChart.svg(0, 0, 0)).to eq('')
    end

    it 'omits a zero-count segment and gives the sole segment the full circumference' do
      svg = HtmlRingChart.svg(3, 0, 0)
      expect(svg.scan('<circle').length).to eq(1)
      expect(svg).to include('stroke="#27ae60"')

      circumference = 2 * Math::PI * 36
      expect(svg).to include("stroke-dasharray=\"#{circumference.round(3)} 0.0\"")
    end

    it 'splits the circumference proportionally across passed/failed/ignored segments' do
      svg = HtmlRingChart.svg(1, 1, 1)
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

    it 'HTML-escapes a test name and failure message containing markup' do
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

    it 'omits the table for a category with no tests' do
      results[:ignores] = []
      stream = StringIO.new
      reporter.body(stream: stream, name: 'x', results: results, duration_s: nil)

      expect(stream.string).not_to include('table class="ignored"')
    end

    it 'shows a dash for a failure with no message' do
      results[:failures].first[:collection].first[:message] = ''
      stream = StringIO.new
      reporter.body(stream: stream, name: 'x', results: results, duration_s: nil)

      expect(stream.string).to include('<td class="col-message">—</td>')
    end

    # The threshold counts the message's own characters, before escaping lengthens it
    it 'collapses a message longer than 150 characters behind a disclosure' do
      results[:failures].first[:collection].first[:message] = 'x' * 151
      stream = StringIO.new
      reporter.body(stream: stream, name: 'x', results: results, duration_s: nil)

      expect(stream.string).to include('<details><summary>Message hidden due to long length.</summary>')
    end

    it 'shows a 150-character message inline' do
      results[:failures].first[:collection].first[:message] = 'x' * 150
      stream = StringIO.new
      reporter.body(stream: stream, name: 'x', results: results, duration_s: nil)

      expect(stream.string).not_to include('<details>')
    end
  end

  describe '#header' do
    def title(name)
      stream = StringIO.new
      reporter.header(stream: stream, name: name, results: results, duration_s: nil)
      stream.string[%r{<title>(.*)</title>}, 1]
    end

    it 'titles a report with the default name plainly' do
      expect(title(TestsReporter::DEFAULT_REPORT_NAME)).to eq('Ceedling Test Suite Report')
    end

    it 'titles a report with a project name after the suite' do
      expect(title('Q-36 Modulator')).to eq('Ceedling Test Suite: Q-36 Modulator')
    end

    it 'escapes a project name in the title' do
      expect(title('Q-36 & <Modulator>')).to eq('Ceedling Test Suite: Q-36 &amp; &lt;Modulator&gt;')
    end
  end

  describe '#write_summary (private)' do
    it 'shows counts[:passed] as given even when :total disagrees' do
      stream = StringIO.new
      # :total is deliberately stale/wrong; :passed is the real, correct aggregate.
      reporter.send(:write_summary, 'x', { total: 999, passed: 2, failed: 1, ignored: 1 }, nil, stream)

      expect(stream.string).to match(%r{<td>Passed</td><td>2</td>})
    end

    it 'shows the build duration beside the timestamp when known' do
      stream = StringIO.new
      reporter.send(:write_summary, 'x', results[:counts], 65, stream)

      duration = Reportinator.generate_duration_string(65, precision: 0, abbreviate: true)
      expect(stream.string).to include(%(class="datetime-row">#{duration} ⏱️ ))
    end

    it 'shows a dash for the pass percentage when no tests ran' do
      stream = StringIO.new
      reporter.send(:write_summary, 'x', { total: 0, passed: 0, failed: 0, ignored: 0 }, nil, stream)

      expect(stream.string).to include('<div class="pct-value">—</div>')
    end
  end
end
