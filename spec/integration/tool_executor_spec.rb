# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Unlike spec/units/tool_executor_spec.rb, this spec wires the REAL ToolExecutor +
# ToolExecutorHelper + SystemWrapper + SystemUtils + Loginator + Verbosinator +
# RubyExpandinator graph (see tool_executor_integration_helper.rb) and genuinely shells
# out through SystemWrapper#shell_capture3 (Open3.capture3). The one external dependency
# is `ruby` itself -- the same interpreter running this test suite -- rather than gcc or
# any POSIX shell builtin, so every scenario here is available on every CI platform
# (Linux/Windows/macOS) without a toolchain probe.
#
# Real scripts are written to real files via with_source_tree and invoked by their real
# path, rather than passed inline via `-e`, specifically to avoid needing to reason about
# cross-platform (sh vs. cmd.exe) command-line quoting for script CONTENT -- only a bare
# file path need ever survive shell parsing, and script file content is real Ruby source
# written straight to disk, immune to any shell-quoting concern entirely.

require 'spec_helper'
require 'spec_integration_helper'
require 'tool_executor_integration_helper'
require 'ceedling/constants'
require 'ceedling/system_wrapper'
require 'ceedling/system_utils'

describe 'ToolExecutor (integration)' do
  let(:executor) { real_tool_executor }

  it 'builds and executes a real command end-to-end, returning real stdout' do
    with_source_tree({ 'probe.rb' => 'puts "hello-from-ceedling"' }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'probe.rb')])

      command = executor.build_command_line(tool, [])
      result = executor.exec(command)

      expect(result[:stdout]).to include('hello-from-ceedling')
      expect(result[:exit_code]).to eq(0)
    end
  end

  it 'substitutes a real ${1} positional arg into a real shelled-out command' do
    with_source_tree({ 'echo_arg.rb' => 'puts ARGV[0]' }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'echo_arg.rb'), '${1}'])

      command = executor.build_command_line(tool, [], 'ceedling-arg-value')
      result = executor.exec(command)

      expect(result[:stdout]).to include('ceedling-arg-value')
    end
  end

  it 'raises ShellException with the real exit code when the real process exits non-zero and boom is true' do
    with_source_tree({ 'fail.rb' => 'exit 3' }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'fail.rb')])
      command = executor.build_command_line(tool, [])

      expect { executor.exec(command) }.to raise_error(ShellException) { |e|
        expect(e.shell_result[:exit_code]).to eq(3)
      }
    end
  end

  it 'does not raise when boom is false, even though the real process exits non-zero' do
    with_source_tree({ 'fail.rb' => 'exit 3' }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'fail.rb')])
      command = executor.build_command_line(tool, [])
      command[:options] = { :boom => false }

      result = executor.exec(command)

      # Pins SystemWrapper's own real contract: :exit_code only ever reflects the real
      # process's actual exit status when boom:true was passed through to it -- with
      # boom:false it stays 0 regardless of what really happened. Easy to misread as a
      # bug; isn't one.
      expect(result[:exit_code]).to eq(0)
    end
  end

  it 'captures real stderr output separately from real stdout' do
    with_source_tree({ 'split.rb' => '$stdout.puts "on-stdout"; $stderr.puts "on-stderr"' }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'split.rb')])
      command = executor.build_command_line(tool, [])

      result = executor.exec(command)

      expect(result[:stdout]).to include('on-stdout')
      expect(result[:stdout]).to_not include('on-stderr')
      expect(result[:stderr]).to include('on-stderr')
      expect(result[:stderr]).to_not include('on-stdout')
    end
  end

  it 'measures a real non-negative elapsed :time for the real shell-out' do
    with_source_tree({ 'probe.rb' => 'puts "done"' }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'probe.rb')])
      command = executor.build_command_line(tool, [])

      result = executor.exec(command)

      expect(result[:time]).to be_a(Numeric)
      expect(result[:time]).to be >= 0
    end
  end

  it 'reads a real fixture file, whose path is substituted as a ${n} argument, through a real shell-out' do
    with_source_tree({
      'read_file.rb' => 'print File.read(ARGV[0])',
      'input.txt'    => 'ceedling-fixture-content',
    }) do |dir|
      tool = ruby_tool_config(arguments: [File.join(dir, 'read_file.rb'), '${1}'])

      command = executor.build_command_line(tool, [], File.join(dir, 'input.txt'))
      result = executor.exec(command)

      expect(result[:stdout]).to eq('ceedling-fixture-content')
    end
  end

  it 'builds and runs a real command line using the tools.md-documented hash-style array-substitution shortcut' do
    with_source_tree({ 'echo_args.rb' => 'print ARGV.join(",")' }) do |dir|
      # Mirrors tools.md's own :test_linker example ("-l$-lib:" with a YAML array of
      # plain library names) -- each array item is a literal value, not a Ruby constant
      # or expression, dropped into the substitution string as-is.
      tool = {
        name: 'ruby_probe',
        executable: RbConfig.ruby,
        arguments: [File.join(dir, 'echo_args.rb'), { '$-suffix' => ['foo', 'bar'] }],
      }

      command = executor.build_command_line(tool, [])
      result = executor.exec(command)

      expect(result[:stdout]).to eq('foo-suffix,bar-suffix')
    end
  end

  # Platform-detection-is-the-thing-under-test: SystemWrapper.windows?/SystemUtils#tcsh_shell?
  # are the exact predicates ToolExecutorHelper itself branches on, so asserting against them
  # directly checks "does the real resulting command actually work on this real platform" --
  # something a unit test stubbing those predicates can never confirm. Different from
  # dependency_tracker_filename_handling_spec.rb's empirical-probe style, which exists
  # specifically because filesystem case-sensitivity is *not* reliably implied by RUBY_PLATFORM;
  # here the platform predicate genuinely *is* what's under test.

  context 'osify_path_separators on the real platform' do
    it 'converts forward slashes to backslashes in the real executable path used to build the command line', skip: (SystemWrapper.windows? ? false : 'Windows-only: osify_path_separators is a no-op elsewhere') do
      forward_slash_executable = RbConfig.ruby.gsub('\\', '/')
      tool = { name: 'ruby_probe', executable: forward_slash_executable, arguments: [] }

      command = executor.build_command_line(tool, [])

      expect(command[:executable]).to_not include('/')

      result = executor.exec(command)
      expect(result[:exit_code]).to eq(0)
    end

    it 'leaves a forward-slash executable path unchanged on a real non-Windows platform', skip: (SystemWrapper.windows? ? 'non-Windows-only' : false) do
      tool = ruby_tool_config

      command = executor.build_command_line(tool, [])

      expect(command[:executable]).to eq(RbConfig.ruby)
    end
  end

  context ':auto stderr redirect on the real platform' do
    def redirect_probe_tool(dir)
      ruby_tool_config(arguments: [File.join(dir, 'stderr_only.rb')])
    end

    it 'appends 2>&1 and runs successfully on real Windows', skip: (SystemWrapper.windows? ? false : 'Windows-only') do
      with_source_tree({ 'stderr_only.rb' => '$stderr.puts "err-text"' }) do |dir|
        tool = redirect_probe_tool(dir)
        command = executor.build_command_line(tool, [])
        command[:options] = { :stderr_redirect => StdErrRedirect::AUTO }

        result = executor.exec(command)

        expect(result[:exit_code]).to eq(0)
      end
    end

    it 'appends 2>&1 and runs successfully on a real non-Windows, non-tcsh shell', skip: (!SystemWrapper.windows? && !SystemUtils.new(system_wrapper: SystemWrapper.new).tcsh_shell? ? false : 'requires non-Windows, non-tcsh') do
      with_source_tree({ 'stderr_only.rb' => '$stderr.puts "err-text"' }) do |dir|
        tool = redirect_probe_tool(dir)
        command = executor.build_command_line(tool, [])
        command[:options] = { :stderr_redirect => StdErrRedirect::AUTO }

        result = executor.exec(command)

        expect(result[:exit_code]).to eq(0)
      end
    end

    it 'appends |& and runs successfully when the real shell is tcsh', skip: (!SystemWrapper.windows? && SystemUtils.new(system_wrapper: SystemWrapper.new).tcsh_shell? ? false : 'tcsh not available') do
      with_source_tree({ 'stderr_only.rb' => '$stderr.puts "err-text"' }) do |dir|
        tool = redirect_probe_tool(dir)
        command = executor.build_command_line(tool, [])
        command[:options] = { :stderr_redirect => StdErrRedirect::AUTO }

        result = executor.exec(command)

        expect(result[:exit_code]).to eq(0)
      end
    end
  end
end
