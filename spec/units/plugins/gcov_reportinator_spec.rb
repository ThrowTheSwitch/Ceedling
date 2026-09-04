# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcov_types'
require 'gcov_reportinator'

# GcovReportinator is abstract -- a bare instance exercises the shared,
# concrete pieces every subclass inherits (version gating, custom-args
# escape hatch, the declarative argument-table builder) without pulling in
# either subclass's own tool-specific setup.
describe GcovReportinator do
  let(:reportinator) { described_class.new({}) }

  describe '#min_version?' do
    it 'is true when the major version exceeds the floor' do
      expect( reportinator.send(:min_version?, ToolVersion.new(9, 0), 8, 0) ).to eq(true)
    end

    it 'is true when major matches and minor meets the floor' do
      expect( reportinator.send(:min_version?, ToolVersion.new(8, 3), 8, 0) ).to eq(true)
    end

    it 'is false when major matches but minor is below the floor' do
      expect( reportinator.send(:min_version?, ToolVersion.new(8, 0), 8, 1) ).to eq(false)
    end

    it 'is false when the major version is below the floor' do
      expect( reportinator.send(:min_version?, ToolVersion.new(5, 9), 6, 0) ).to eq(false)
    end
  end

  describe '#detect_tool_version' do
    it 'parses major.minor from the tool output using the given pattern' do
      tool_executor = double('tool_executor')
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "gcovr 8.3 (foo)\n" })
      reportinator.instance_variable_set(:@tool_executor, tool_executor)

      version = reportinator.send(:detect_tool_version, {}, /gcovr (\d+)\.(\d+)/, tool_label: 'gcovr')
      expect(version.major).to eq(8)
      expect(version.minor).to eq(3)
    end

    it 'raises CeedlingException when the pattern does not match' do
      tool_executor = double('tool_executor')
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "not a version string\n" })
      reportinator.instance_variable_set(:@tool_executor, tool_executor)

      expect {
        reportinator.send(:detect_tool_version, {}, /gcovr (\d+)\.(\d+)/, tool_label: 'gcovr')
      }.to raise_error(CeedlingException, /Could not collect `gcovr` version/)
    end
  end

  describe '#enforce_version_gates!' do
    let(:gate_table) do
      {
        :decisions => { min: [5, 1], message: ":gcov ↳ :gcovr ↳ :decisions ➡️ requires gcovr %{req} or higher (found %{found})" },
        :mcdc      => { min: [8, 0], message: ":gcov ↳ :mcdc ➡️ requires gcovr %{req} or higher (found %{found})" },
      }
    end

    it 'does nothing when every configured option meets its floor' do
      expect {
        reportinator.send(:enforce_version_gates!, { decisions: true, mcdc: nil }, ToolVersion.new(8, 3), gate_table)
      }.to_not raise_error
    end

    it 'ignores an option nobody configured (nil) even if its floor would fail' do
      expect {
        reportinator.send(:enforce_version_gates!, { decisions: nil, mcdc: nil }, ToolVersion.new(1, 0), gate_table)
      }.to_not raise_error
    end

    it 'ignores a boolean option explicitly set false' do
      expect {
        reportinator.send(:enforce_version_gates!, { decisions: false, mcdc: nil }, ToolVersion.new(1, 0), gate_table)
      }.to_not raise_error
    end

    it 'raises CeedlingException naming the option, required version, and found version' do
      expect {
        reportinator.send(:enforce_version_gates!, { decisions: true, mcdc: nil }, ToolVersion.new(5, 0), gate_table)
      }.to raise_error(CeedlingException, /:decisions.*requires gcovr 5\.1 or higher \(found 5\.0\)/)
    end

    it 'collects every violated gate into one exception rather than only the first' do
      expect {
        reportinator.send(:enforce_version_gates!, { decisions: true, mcdc: true }, ToolVersion.new(4, 0), gate_table)
      }.to raise_error(CeedlingException) { |ex|
        expect(ex.message).to match(/:decisions/)
        expect(ex.message).to match(/:mcdc/)
      }
    end
  end

  describe '#build_custom_args' do
    it 'quotes each argument and skips nil/empty entries' do
      result = reportinator.send(:build_custom_args, ['--foo', '', nil, '--bar=1'])
      expect(result).to eq('"--foo" "--bar=1" ')
    end

    it 'returns an empty string when custom_args is nil' do
      expect( reportinator.send(:build_custom_args, nil) ).to eq('')
    end
  end

  describe '#build_args_from_table' do
    it 'emits a boolean flag alone when true, and omits it when false/nil' do
      table = { flag_on: { type: :boolean, flag: '--flag-on' } }
      expect( reportinator.send(:build_args_from_table, { flag_on: true }, table) ).to eq('--flag-on ')
      expect( reportinator.send(:build_args_from_table, { flag_on: false }, table) ).to eq('')
      expect( reportinator.send(:build_args_from_table, {}, table) ).to eq('')
    end

    it 'quotes a :value entry by default and honors quote: false' do
      table = {
        quoted:   { type: :value, flag: '--quoted' },
        unquoted: { type: :value, flag: '--unquoted', quote: false },
      }
      result = reportinator.send(:build_args_from_table, { quoted: 'a b', unquoted: 'a b' }, table)
      expect(result).to include('--quoted "a b" ')
      expect(result).to include('--unquoted a b ')
    end

    it 'combines flag and value into one quoted token for :inline_value' do
      table = { historydir: { type: :inline_value, flag: '-historydir:' } }
      result = reportinator.send(:build_args_from_table, { historydir: '/tmp/hist' }, table)
      expect(result).to eq('"-historydir:/tmp/hist" ')
    end

    it 'repeats the flag once per entry for :list' do
      table = { includes: { type: :list, flag: '--include' } }
      result = reportinator.send(:build_args_from_table, { includes: ['a', 'b'] }, table)
      expect(result).to eq('--include "a" --include "b" ')
    end

    it 'emits :integer only when the value really is an Integer' do
      table = { threads: { type: :integer, flag: '-j' } }
      expect( reportinator.send(:build_args_from_table, { threads: 4 }, table) ).to eq('-j 4 ')
      expect( reportinator.send(:build_args_from_table, { threads: '4' }, table) ).to eq('')
    end

    it 'raises CeedlingException for a non-Integer :integer_percent value' do
      table = { fail_under_line: { type: :integer_percent, flag: '--fail-under-line' } }
      expect {
        reportinator.send(:build_args_from_table, { fail_under_line: '50' }, table, component_prefix: ':gcov ↳ :gcovr')
      }.to raise_error(CeedlingException, /must be an integer/)
    end

    it 'raises CeedlingException for an :integer_percent value outside 1-100' do
      table = { fail_under_line: { type: :integer_percent, flag: '--fail-under-line' } }
      expect {
        reportinator.send(:build_args_from_table, { fail_under_line: 0 }, table, component_prefix: ':gcov ↳ :gcovr')
      }.to raise_error(CeedlingException, /must be an integer percentage/)

      expect {
        reportinator.send(:build_args_from_table, { fail_under_line: 101 }, table, component_prefix: ':gcov ↳ :gcovr')
      }.to raise_error(CeedlingException, /must be an integer percentage/)
    end

    it 'accepts the boundary values 1 and 100 for :integer_percent' do
      table = { fail_under_line: { type: :integer_percent, flag: '--fail-under-line' } }
      expect( reportinator.send(:build_args_from_table, { fail_under_line: 1 }, table, component_prefix: ':gcov') ).to eq('--fail-under-line 1 ')
      expect( reportinator.send(:build_args_from_table, { fail_under_line: 100 }, table, component_prefix: ':gcov') ).to eq('--fail-under-line 100 ')
    end

    it 'resolves a Proc :flag using the given version' do
      table = {
        branches: {
          type: :boolean,
          flag: ->(v) { ToolVersionGating.min_version?(v, 7, 0) ? '--txt-metric branch' : '--branches' }
        }
      }
      old = reportinator.send(:build_args_from_table, { branches: true }, table, version: ToolVersion.new(6, 9))
      new = reportinator.send(:build_args_from_table, { branches: true }, table, version: ToolVersion.new(7, 0))
      expect(old).to eq('--branches ')
      expect(new).to eq('--txt-metric branch ')
    end

    it 'silently omits an entry whose min_version the given version does not meet' do
      table = { merge_mode_function: { type: :value, flag: '--merge-mode-functions', min_version: [6, 0] } }
      expect( reportinator.send(:build_args_from_table, { merge_mode_function: 'strict' }, table, version: ToolVersion.new(5, 9)) ).to eq('')
      expect( reportinator.send(:build_args_from_table, { merge_mode_function: 'strict' }, table, version: ToolVersion.new(6, 0)) ).to include('--merge-mode-functions "strict"')
    end
  end

  describe '#build_exclusion_data' do
    it 'reads test/support paths, prefixes, build root, and source extension from the configurator' do
      configurator = double('configurator',
        collection_paths_test:    ['test'],
        collection_paths_support: ['support'],
        project_test_file_prefix: 'test_',
        cmock_mock_prefix:        'Mock',
        project_build_root:       'build',
        extension_source:         '.c'
      )
      reportinator.instance_variable_set(:@configurator, configurator)

      data = reportinator.send(:build_exclusion_data)
      expect(data).to eq({
        test_paths:    ['test'],
        support_paths: ['support'],
        test_prefix:   'test_',
        mock_prefix:   'Mock',
        build_root:    'build',
        src_extension: '.c'
      })
    end
  end
end
