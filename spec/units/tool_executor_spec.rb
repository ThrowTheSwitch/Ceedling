# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/tool_executor'
require 'ceedling/ruby_expandinator'
require 'ceedling/exceptions'

# Scoped narrowly to the inline Ruby string expansion (--ruby-replacement) behavior
# introduced by RubyExpandinator. Broader ToolExecutor coverage is a pre-existing gap
# outside this feature's scope.
describe ToolExecutor do
  before(:each) do
    @tool_executor_helper = double('tool_executor_helper').as_null_object
    allow(@tool_executor_helper).to receive(:osify_path_separators) {|s| s}
    @loginator = double('loginator').as_null_object
    @verbosinator = double('verbosinator').as_null_object
    @system_wrapper = double('system_wrapper').as_null_object
    # Default to "not a recognized constant" so a plain, non-constant hash-substitution
    # string value doesn't fall through to Object.const_get via the null object's default
    # truthy response -- individual examples override this to simulate a real constant.
    allow(@system_wrapper).to receive(:constants_include?).and_return(false)
    @ruby_expandinator = RubyExpandinator.new

    @tool_executor = described_class.new(
      {
        :tool_executor_helper => @tool_executor_helper,
        :loginator => @loginator,
        :verbosinator => @verbosinator,
        :system_wrapper => @system_wrapper,
        :ruby_expandinator => @ruby_expandinator
      }
    )
  end

  describe '#build_command_line — :executable expansion' do
    it 'raises CeedlingException when :executable contains a Ruby replacement pattern and the feature is disabled' do
      tool_config = { :name => 'my_tool', :executable => '#{1+1}' }

      expect {
        @tool_executor.build_command_line( tool_config, [] )
      }.to raise_error(CeedlingException, /my_tool/)
    end

    it 'expands :executable when the feature is enabled' do
      @ruby_expandinator.enable!
      tool_config = { :name => 'my_tool', :executable => '#{1+1}' }

      command = @tool_executor.build_command_line( tool_config, [] )

      expect(command[:executable]).to eq('2')
    end
  end

  describe '#build_command_line — hash-style :arguments expansion' do
    it 'raises CeedlingException when an argument hash value contains a Ruby replacement pattern and the feature is disabled' do
      tool_config = {
        :name => 'my_tool',
        :executable => 'compiler',
        :arguments => [ { '--flag=$' => '#{1+1}' } ]
      }

      expect {
        @tool_executor.build_command_line( tool_config, [] )
      }.to raise_error(CeedlingException, /my_tool/)
    end

    it 'expands an argument hash value when the feature is enabled' do
      @ruby_expandinator.enable!
      tool_config = {
        :name => 'my_tool',
        :executable => 'compiler',
        :arguments => [ { '--flag=$' => '#{1+1}' } ]
      }

      command = @tool_executor.build_command_line( tool_config, [] )

      expect(command[:line]).to include('--flag=2')
    end
  end

  describe '.default_name!' do
    it 'sets tool[:name] to the default when tool[:name] is nil' do
      tool = { :name => nil }

      ToolExecutor.default_name!(tool, 'fallback_name')

      expect(tool[:name]).to eq('fallback_name')
    end

    it 'sets tool[:name] to the default when the :name key is absent entirely' do
      tool = {}

      ToolExecutor.default_name!(tool, 'fallback_name')

      expect(tool[:name]).to eq('fallback_name')
    end

    it 'leaves tool[:name] unchanged when already set' do
      tool = { :name => 'explicit_name' }

      ToolExecutor.default_name!(tool, 'fallback_name')

      expect(tool[:name]).to eq('explicit_name')
    end
  end

  describe '#exec' do
    before(:each) do
      @command = { :name => 'my_tool', :executable => 'my_tool', :line => 'my_tool --flag', :options => {} }
    end

    def stub_shell_capture3(result)
      allow(@system_wrapper).to receive(:shell_capture3).and_return(result)
    end

    it 'defaults options[:boom] to true when not specified' do
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 })

      @tool_executor.exec(@command)

      expect(@system_wrapper).to have_received(:shell_capture3).with(hash_including(boom: true))
    end

    it 'defaults options[:stderr_redirect] to StdErrRedirect::NONE when not specified' do
      allow(@tool_executor_helper).to receive(:stderr_redirect_cmdline_append)
        .with(hash_including(stderr_redirect: StdErrRedirect::NONE))
        .and_return(nil)
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 })

      @tool_executor.exec(@command)

      expect(@tool_executor_helper).to have_received(:stderr_redirect_cmdline_append)
    end

    it 'preserves an explicitly-set options[:boom] of false' do
      @command[:options] = { :boom => false }
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'err', :exit_code=>1 })

      expect { @tool_executor.exec(@command) }.to_not raise_error
    end

    it 'builds command_line by joining command[:line], args, and the stderr redirect append string' do
      @command[:line] = 'gcc -c a.c'
      allow(@tool_executor_helper).to receive(:stderr_redirect_cmdline_append).and_return('2>&1')
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 })

      @tool_executor.exec(@command, ['extra1', 'extra2'])

      expect(@system_wrapper).to have_received(:shell_capture3).with(command: 'gcc -c a.c extra1 extra2 2>&1', boom: true)
    end

    it 'omits the stderr redirect segment when stderr_redirect_cmdline_append returns nil' do
      @command[:line] = 'gcc -c a.c'
      allow(@tool_executor_helper).to receive(:stderr_redirect_cmdline_append).and_return(nil)
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 })

      @tool_executor.exec(@command)

      expect(@system_wrapper).to have_received(:shell_capture3).with(command: 'gcc -c a.c', boom: true)
    end

    it 'flattens and compacts args before joining into the shelled command line' do
      @command[:line] = 'tool'
      allow(@tool_executor_helper).to receive(:stderr_redirect_cmdline_append).and_return(nil)
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 })

      @tool_executor.exec(@command, [['a', 'b'], nil, 'c'])

      expect(@system_wrapper).to have_received(:shell_capture3).with(command: 'tool a b c', boom: true)
    end

    it 'returns a shell_result hash containing :time measured via Benchmark.realtime' do
      stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 })

      result = @tool_executor.exec(@command)

      expect(result[:time]).to be_a(Numeric)
      expect(result[:time]).to be >= 0
    end

    context 'when shell_capture3 raises' do
      before(:each) do
        allow(@system_wrapper).to receive(:shell_capture3).and_raise(StandardError, 'boom')
      end

      it 'wraps the raised error in a ShellException' do
        expect { @tool_executor.exec(@command) }.to raise_error(ShellException)
      end

      it 'includes the pretty tool name, command line, and original error message in the wrapped exception' do
        begin
          @tool_executor.exec(@command)
        rescue ShellException => e
          expect(e.message).to include("'My Tool'")
          expect(e.message).to include('my_tool --flag')
          expect(e.message).to include('boom')
        end
      end

      it 'still calls log_results in ensure even though shell_capture3 raised' do
        allow(@tool_executor_helper).to receive(:log_results)

        expect { @tool_executor.exec(@command) }.to raise_error(ShellException)

        expect(@tool_executor_helper).to have_received(:log_results)
      end

      it 'passes the default all-empty shell_result hash to log_results' do
        allow(@tool_executor_helper).to receive(:log_results)

        expect { @tool_executor.exec(@command) }.to raise_error(ShellException)

        expect(@tool_executor_helper).to have_received(:log_results).with(
          anything, hash_including(:output => '', :stdout => '', :stderr => '', :exit_code => 0)
        )
      end
    end

    context 'when the real exit code is non-zero' do
      it 'raises a ShellException when boom is true (the default)' do
        stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'err', :exit_code=>2 })

        expect { @tool_executor.exec(@command) }.to raise_error(ShellException)
      end

      it 'passes shell_result: (with the real exit code) to the ShellException' do
        stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'err', :exit_code=>2 })

        begin
          @tool_executor.exec(@command)
        rescue ShellException => e
          expect(e.shell_result[:exit_code]).to eq(2)
        end
      end

      it 'does not raise when boom is false' do
        @command[:options] = { :boom => false }
        stub_shell_capture3({ :output=>'', :stdout=>'', :stderr=>'err', :exit_code=>2 })

        result = @tool_executor.exec(@command)

        expect(result[:exit_code]).to eq(2)
      end
    end

    it 'replaces an invalid byte sequence in shell_result[:output] with the Unicode replacement character via String#scrub' do
      stub_shell_capture3({ :output=>"abc\xFF".dup, :stdout=>'', :stderr=>'', :exit_code=>0 })

      result = @tool_executor.exec(@command)

      expect(result[:output]).to eq("abc�")
    end

    it 'strips ANSI SGR codes from shell_result[:output], including single-digit codes like reset and bold' do
      stub_shell_capture3({ :output=>"\e[1mtext\e[0m".dup, :stdout=>'', :stderr=>'', :exit_code=>0 })

      result = @tool_executor.exec(@command)

      expect(result[:output]).to eq('text')
    end

    it 'strips a semicolon-joined multi-part ANSI SGR code' do
      stub_shell_capture3({ :output=>"\e[1;31mbold red\e[0m".dup, :stdout=>'', :stderr=>'', :exit_code=>0 })

      result = @tool_executor.exec(@command)

      expect(result[:output]).to eq('bold red')
    end

    it 'does not raise when shell_result[:output] is nil' do
      stub_shell_capture3({ :output=>nil, :stdout=>'', :stderr=>'', :exit_code=>0 })

      expect { @tool_executor.exec(@command) }.to_not raise_error
    end

    it 'calls log_results with the fully joined command_line string and the shell_result' do
      @command[:line] = 'gcc -c a.c'
      allow(@tool_executor_helper).to receive(:stderr_redirect_cmdline_append).and_return(nil)
      allow(@tool_executor_helper).to receive(:log_results)
      shell_result = { :output=>'', :stdout=>'', :stderr=>'', :exit_code=>0 }
      stub_shell_capture3(shell_result)

      @tool_executor.exec(@command)

      expect(@tool_executor_helper).to have_received(:log_results).with('gcc -c a.c', hash_including(:exit_code => 0))
    end
  end

  describe '#build_command_line' do
    it 'sets command[:name] from tool_config[:name]' do
      tool_config = { :name => 'my_tool', :executable => 'exe' }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:name]).to eq('my_tool')
    end

    it 'sets command[:options] to an empty hash' do
      tool_config = { :name => 'my_tool', :executable => 'exe' }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:options]).to eq({})
    end

    it "calls tool_executor_helper.osify_path_separators on the expanded executable and uses its result for command[:executable]" do
      allow(@tool_executor_helper).to receive(:osify_path_separators).and_return('osified/path')
      tool_config = { :name => 'my_tool', :executable => 'exe' }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:executable]).to eq('osified/path')
    end

    it 'joins executable, extra_params, and built arguments into command[:line], rejecting empty segments' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['--flag'] }

      command = @tool_executor.build_command_line(tool_config, ['--extra'])

      expect(command[:line]).to eq('exe --extra --flag')
    end

    it 'omits extra_params entirely from command[:line] when extra_params is empty' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['--flag'] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to eq('exe --flag')
    end

    it 'omits the arguments segment from command[:line] when tool_config[:arguments] is nil' do
      tool_config = { :name => 't', :executable => 'exe' }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to eq('exe')
    end

    it 'calls loginator.lazy with Verbosity::DEBUG' do
      allow(@loginator).to receive(:lazy)
      tool_config = { :name => 't', :executable => 'exe' }

      @tool_executor.build_command_line(tool_config, [])

      expect(@loginator).to have_received(:lazy).with(Verbosity::DEBUG)
    end
  end

  describe '#build_command_line — :arguments building' do
    it 'dispatches a String argument element through ${n} expansion' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['-c'] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('-c')
    end

    it 'dispatches a Hash argument element through hash-style substitution' do
      allow(@system_wrapper).to receive(:constants_include?).with('RUBY_VERSION').and_return(true)
      tool_config = { :name => 't', :executable => 'exe', :arguments => [{ '-D$' => 'RUBY_VERSION' }] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include("-D#{RUBY_VERSION}")
    end

    it 'flattens nested/aliased arrays within :arguments before dispatching each element' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => [['-a', ['-b', '-c']]] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line].split(' ')).to include('-a', '-b', '-c')
    end

    it 'skips an empty-string argument element without leaving stray whitespace, matching DEFAULT_TEST_LINKER_TOOL-style deliberately-empty slots' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['${1}', '${5}', '-o "${2}"', '', '${4}'] }

      command = @tool_executor.build_command_line(tool_config, [], 'obj1.o', 'out.o', 'map.map', 'deps.d', '-Iinc')

      expect(command[:line]).to_not include('  ')
    end
  end

  describe '#build_command_line — ${n} argument replacement (String arguments)' do
    it 'replaces ${1} with the first positional arg (1-indexed to 0-indexed conversion)' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['${1}'] }

      command = @tool_executor.build_command_line(tool_config, [], 'value_a')

      expect(command[:line]).to include('value_a')
    end

    it 'replaces ${2} with the second positional arg' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['${2}'] }

      command = @tool_executor.build_command_line(tool_config, [], 'a', 'b')

      expect(command[:line]).to include('b')
    end

    it 'substitutes only the ${n} token within a larger element string, preserving surrounding text/quoting' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['-o "${2}"'] }

      command = @tool_executor.build_command_line(tool_config, [], 'a', 'out.o')

      expect(command[:line]).to include('-o "out.o"')
    end

    it 'raises CeedlingException when args is empty but a ${n} element is present' do
      tool_config = { :name => 'my_tool', :executable => 'exe', :arguments => ['${1}'] }

      expect {
        @tool_executor.build_command_line(tool_config, [])
      }.to raise_error(CeedlingException, /expects argument data but was provided none/)
    end

    it 'raises CeedlingException when ${n} references an index beyond the number of args provided' do
      tool_config = { :name => 'my_tool', :executable => 'exe', :arguments => ['${3}'] }

      expect {
        @tool_executor.build_command_line(tool_config, [], 'only_one')
      }.to raise_error(CeedlingException, /provided only 1 arguments/)
    end

    it 'fans an Array-valued positional arg out into one repeated argument per element' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['-I"${1}"'] }

      command = @tool_executor.build_command_line(tool_config, [], ['dir1', 'dir2'])

      expect(command[:line]).to include('-I"dir1"')
      expect(command[:line]).to include('-I"dir2"')
    end

    it 'contributes nothing when the Array-valued positional arg is empty' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['-I"${1}"'] }

      command = @tool_executor.build_command_line(tool_config, [], [])

      expect(command[:line]).to eq('exe')
    end

    it 'unescapes a literal \$ in a plain-string argument with no ${n} pattern' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['\$literal'] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('$literal')
    end

    it 'strips leading/trailing whitespace from a plain-string argument element' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['  -c  '] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to eq('exe -c')
    end

    it 'passes a plain-string argument through ruby_expandinator.expand as a no-op when it contains no Ruby-replacement pattern' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['plain-arg'] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('plain-arg')
    end

    it 'produces literal ${1} text (not the substituted argument value) for an escaped \${1} argument' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['\${1}'] }

      command = @tool_executor.build_command_line(tool_config, [], 'X')

      expect(command[:line]).to include('${1}')
      expect(command[:line]).to_not include('X')
    end

    it 'still substitutes a normal, non-escaped ${1} elsewhere, confirming the escape fix does not disturb the ordinary case' do
      tool_config = { :name => 't', :executable => 'exe', :arguments => ['${1}'] }

      command = @tool_executor.build_command_line(tool_config, [], 'X')

      expect(command[:line]).to include('X')
    end
  end

  describe '#build_command_line — Hash-style :arguments (non-Ruby-expansion paths)' do
    it 'raises CeedlingException naming the substitution string when the hash value is nil' do
      tool_config = { :name => 'my_tool', :executable => 'exe', :arguments => [{ '-D$' => nil }] }

      expect {
        @tool_executor.build_command_line(tool_config, [])
      }.to raise_error(CeedlingException, /-D\$/)
    end

    it 'resolves a String value naming a real global constant via system_wrapper.constants_include? + Object.const_get' do
      allow(@system_wrapper).to receive(:constants_include?).with('RUBY_VERSION').and_return(true)
      tool_config = { :name => 't', :executable => 'exe', :arguments => [{ '-v$' => 'RUBY_VERSION' }] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include("-v#{RUBY_VERSION}")
    end

    it 'raises CeedlingException when the resolved constant value is nil' do
      Object.const_set(:CEEDLING_SPEC_TOOL_EXECUTOR_NIL_CONST, nil) unless Object.const_defined?(:CEEDLING_SPEC_TOOL_EXECUTOR_NIL_CONST)
      allow(@system_wrapper).to receive(:constants_include?).with('CEEDLING_SPEC_TOOL_EXECUTOR_NIL_CONST').and_return(true)
      tool_config = { :name => 'my_tool', :executable => 'exe', :arguments => [{ '-v$' => 'CEEDLING_SPEC_TOOL_EXECUTOR_NIL_CONST' }] }

      expect {
        @tool_executor.build_command_line(tool_config, [])
      }.to raise_error(CeedlingException, /CEEDLING_SPEC_TOOL_EXECUTOR_NIL_CONST.*nil/)
    end

    it "uses a plain String value directly as a literal when it's neither a Ruby-replacement pattern nor a recognized constant" do
      allow(@system_wrapper).to receive(:constants_include?).and_return(false)
      tool_config = { :name => 'my_tool', :executable => 'exe', :arguments => [{ '-D$' => 'FOO' }] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('-DFOO')
    end

    it 'treats an Array hash value as a list of literal elements, each producing its own repeated argument -- the tools.md-documented -l$-lib shortcut' do
      allow(@system_wrapper).to receive(:constants_include?).and_return(false)
      tool_config = { :name => 'test_linker', :executable => 'linker.exe', :arguments => [{ '-l$-lib' => ['foo', 'bar'] }] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('-lfoo-lib')
      expect(command[:line]).to include('-lbar-lib')
    end

    it 'flattens a nested Array item within the hash value into its own separate repeated arguments' do
      allow(@system_wrapper).to receive(:constants_include?).and_return(false)
      tool_config = { :name => 't', :executable => 'exe', :arguments => [{ '-D$' => [['nested1', 'nested2']] }] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('-Dnested1')
      expect(command[:line]).to include('-Dnested2')
    end

    it 'raises CeedlingException for an array item of an unsupported type (e.g. Integer), rather than crashing' do
      tool_config = { :name => 'my_tool', :executable => 'exe', :arguments => [{ '-v$' => [42] }] }

      expect {
        @tool_executor.build_command_line(tool_config, [])
      }.to raise_error(CeedlingException, /cannot expand value having type 'Integer'/)
    end

    it 'unescapes \$ within the built substitution string across multiple joined literal elements, not just the first' do
      allow(@system_wrapper).to receive(:constants_include?).and_return(false)
      tool_config = { :name => 't', :executable => 'exe', :arguments => [{ '\$flag=$' => ['A', 'B'] }] }

      command = @tool_executor.build_command_line(tool_config, [])

      expect(command[:line]).to include('$flag=A')
      expect(command[:line]).to include('$flag=B')
    end
  end

  describe 'pretty_tool_name (via ShellException messages)' do
    before(:each) do
      allow(@system_wrapper).to receive(:shell_capture3).and_return({ :output=>'', :stdout=>'', :stderr=>'', :exit_code=>1 })
    end

    it 'titleizes a space-separated tool name' do
      command = { :name => 'my tool', :executable => 'exe', :line => 'exe', :options => {} }

      begin
        @tool_executor.exec(command)
      rescue ShellException => e
        expect(e.message).to include("'My Tool'")
      end
    end

    it 'titleizes an underscore-separated tool name, converting underscores to spaces' do
      command = { :name => 'default_test_compiler', :executable => 'exe', :line => 'exe', :options => {} }

      begin
        @tool_executor.exec(command)
      rescue ShellException => e
        expect(e.message).to include("'Default Test Compiler'")
      end
    end

    it 'falls back to <no executable> when command[:executable] is an empty string' do
      command = { :name => 't', :executable => '', :line => 'exe', :options => {} }

      begin
        @tool_executor.exec(command)
      rescue ShellException => e
        expect(e.message).to include('(<no executable>)')
      end
    end

    it 'includes the literal executable string when non-empty' do
      command = { :name => 't', :executable => '/usr/bin/gcc', :line => 'exe', :options => {} }

      begin
        @tool_executor.exec(command)
      rescue ShellException => e
        expect(e.message).to include('(/usr/bin/gcc)')
      end
    end
  end
end
