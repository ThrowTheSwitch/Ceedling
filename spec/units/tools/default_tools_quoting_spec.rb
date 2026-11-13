# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'shellwords'
require 'yaml'
require 'ceedling/defaults'
require 'ceedling/tools/tool_executor'
require 'ceedling/ruby_expandinator'

require 'ceedling/tools/tool_validator'
require 'ceedling/filename_extension'

Dir[File.expand_path( '../../../plugins/*/config/defaults_*.rb', __dir__ )].each { |defaults| load defaults }

# GH #1373: the default tools that run a test executable named it unquoted, so a path holding
# an apostrophe or a space broke the shell command. Each command here is split as a POSIX
# shell splits it, and every path must come back as one word, exactly as given.
describe 'Default tools' do
  SPECIAL_PATH = "build/test/out/test/o'neil dir/test_q/test_q.out"
  OTHER_PATH   = "src/my dir/o'neil.c"

  DEPENDENCIES_TOOLS = YAML.load_file(
    File.expand_path( '../../../plugins/dependencies/config/defaults.yml', __dir__ ), symbolize_names: true
  )[:tools]

  before(:each) do
    helper = double('tool_executor_helper').as_null_object
    allow(helper).to receive(:osify_path_separators) { |path| path }
    system_wrapper = double('system_wrapper').as_null_object
    allow(system_wrapper).to receive(:constants_include?).and_return( false )

    @tool_executor = ToolExecutor.new(
      {
        :tool_executor_helper => helper,
        :loginator            => double('loginator').as_null_object,
        :verbosinator         => double('verbosinator').as_null_object,
        :system_wrapper       => system_wrapper,
        :ruby_expandinator    => RubyExpandinator.new
      }
    )
  end

  # Configuration hands Ceedling an unfrozen copy of each default tool
  def words(tool, *args)
    Shellwords.split( @tool_executor.build_command_line( Marshal.load( Marshal.dump( tool ) ), [], *args )[:line] )
  end

  {
    'test fixture'                   => DEFAULT_TEST_FIXTURE_TOOL,
    'gcov fixture'                   => DEFAULT_GCOV_FIXTURE_TOOL,
    'Bullseye fixture'               => DEFAULT_BULLSEYE_FIXTURE_TOOL,
  }.each do |name, tool|
    it "names the test executable as one word in the #{name}" do
      expect( words( tool, SPECIAL_PATH ) ).to eq( [SPECIAL_PATH] )
    end
  end

  it 'names the test executable as one word in a simple backtrace rerun' do
    expect( words( DEFAULT_TEST_FIXTURE_SIMPLE_BACKTRACE_TOOL, SPECIAL_PATH, '-n "test_a"' ) ).to eq( [SPECIAL_PATH, '-n', 'test_a'] )
  end

  it 'names the test executable as one word in a gdb backtrace' do
    expect( words( DEFAULT_TEST_BACKTRACE_GDB_TOOL, 'build/gdb.txt', SPECIAL_PATH, '-n "test_a"' ).last( 3 ) ).to eq( [SPECIAL_PATH, '-n', 'test_a'] )
  end

  it 'names each source file as one word for cppcheck' do
    expect( words( DEFAULT_CPPCHECK_TOOL, ['src'], [OTHER_PATH, 'src/b.c'] ).last( 2 ) ).to eq( [OTHER_PATH, 'src/b.c'] )
  end

  it 'names the library and each object as one word for the Dependencies archiver' do
    expect( words( DEPENDENCIES_TOOLS[:deps_linker], [OTHER_PATH, 'b.o'], 'build/my dir/libx.a' ) ).to eq(
      ['ar', 'rcs', 'build/my dir/libx.a', OTHER_PATH, 'b.o']
    )
  end

  it 'names the archive as one word for the Dependencies zip unarchiver' do
    expect( words( DEPENDENCIES_TOOLS[:deps_zip], 'vendor/my dir/x.zip' ) ).to eq( ['unzip', '-o', 'vendor/my dir/x.zip'] )
  end
end

# Tool validation checks every tool's quoting on every build, Ceedling's own tools included,
# so none of them may draw an error or a warning on any platform
describe 'Default tools quoting validation' do
  # Every tool Ceedling and its plugins define: each constant holding one, and each tool in
  # a plugin's YAML defaults
  BUILT_IN_TOOLS = (
    Object.constants.grep( /\ADEFAULT_\w+_TOOL\z/ ).map { |name| [name.to_s, Object.const_get( name )] } +
    Dir[File.expand_path( '../../../plugins/*/config/*.yml', __dir__ )].flat_map do |filepath|
      tools = YAML.load_file( filepath, symbolize_names: true )&.dig( :tools ) || {}
      tools.map { |key, tool| ["#{File.basename( File.dirname( File.dirname( filepath ) ) )} :#{key}", tool] }
    end
  ).freeze

  [false, true].each do |windows|
    it "finds every built-in tool's quoting closed and straight #{windows ? 'on' : 'off'} Windows" do
      loginator = double( 'loginator' )
      system_wrapper = double( 'system_wrapper', windows?: windows, search_paths: ['/bin'] )
      file_wrapper = double( 'file_wrapper', exist?: true )
      validator = ToolValidator.new( file_wrapper: file_wrapper, loginator: loginator, system_wrapper: system_wrapper, ruby_expandinator: RubyExpandinator.new )

      complaints = []
      allow( loginator ).to receive( :log ) { |message, *| complaints << message }

      # 50 core and plugin tools, so a narrowed collection fails here, not silently
      expect( BUILT_IN_TOOLS.size ).to be >= 50
      BUILT_IN_TOOLS.each do |name, tool|
        expect( validator.validate( tool: Marshal.load( Marshal.dump( tool ) ), name: name, extension: FilenameExtension.new( '' ) ) ).to be( true ), name
      end
      expect( complaints ).to eq( [] )
    end
  end
end
