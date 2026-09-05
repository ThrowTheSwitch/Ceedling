# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'stringio'

$: << File.expand_path('../../../../plugins/report_tests_log_factory/lib', __FILE__)
require 'tests_reporter'

describe TestsReporter do
  describe '#initialize' do
    it "falls back to '<handle>.report' so a custom subclass that forgets to call setup still has a usable filename" do
      reporter = described_class.new(handle: :foo_bar)
      expect(reporter.filename).to eq('foo_bar.report')
    end
  end

  describe '#setup' do
    it 'uses a configured filename override in preference to the default' do
      config_walkinator = double('config_walkinator')
      allow(config_walkinator).to receive(:fetch_value)
        .with(:filename, hash: { filename: 'custom.xml' }, default: 'default.xml')
        .and_return(['custom.xml', true])

      reporter = described_class.new(handle: :foo)
      reporter.config_walkinator = config_walkinator
      reporter.config = { filename: 'custom.xml' }
      reporter.setup(default_filename: 'default.xml')

      expect(reporter.filename).to eq('custom.xml')
    end
  end

  describe '#header, #body, #footer' do
    it 'are no-ops by default, so a subclass need only override what it actually renders' do
      reporter = described_class.new(handle: :foo)
      stream = StringIO.new

      expect {
        reporter.header(stream: stream, name: 'x', results: {}, duration_s: nil)
        reporter.body(stream: stream, name: 'x', results: {}, duration_s: nil)
        reporter.footer(stream: stream, name: 'x', results: {}, duration_s: nil)
      }.not_to raise_error

      expect(stream.string).to be_empty
    end
  end

  # --- Fix below this point: written to fail against pre-fix code ---

  describe '#write (fix: writes via an injected file_wrapper, never a raw File)' do
    it 'renders header/body/footer into one buffer and hands the complete contents to file_wrapper.write' do
      reporter_class = Class.new(described_class) do
        def header(stream:, name:, results:, duration_s:) stream << 'H' end
        def body(stream:, name:, results:, duration_s:) stream << 'B' end
        def footer(stream:, name:, results:, duration_s:) stream << 'F' end
      end
      reporter = reporter_class.new(handle: :foo)
      file_wrapper = double('file_wrapper')
      reporter.file_wrapper = file_wrapper

      expect(file_wrapper).to receive(:write).with('some/path.txt', 'HBF')

      reporter.write(name: 'x', filepath: 'some/path.txt', results: {}, duration_s: nil)
    end
  end
end
