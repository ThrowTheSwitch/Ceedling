# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'

$: << File.expand_path('../../../../plugins/compile_commands_json_db/lib', __FILE__)
require 'compile_commands_json_db'

# Unit coverage for the JSON compilation database plugin through a doubled file layer.
# What a real filesystem makes of the written database is proven in
# spec/integration/compile_commands_json_db_spec.rb.
describe CompileCommandsJsonDb do
  let(:database_path) { 'build/artifacts/compile_commands.json' }

  before(:each) do
    stub_const('PROJECT_BUILD_ARTIFACTS_ROOT', 'build/artifacts')

    @file_wrapper = double('file_wrapper')
    @loginator    = double('loginator', log: nil)
    allow(@file_wrapper).to receive(:exist?).with(database_path).and_return(false)
    allow(@file_wrapper).to receive(:write)
  end

  def plugin
    @plugin ||= described_class.new( { file_wrapper: @file_wrapper, loginator: @loginator }, 'compile_commands_json_db', '/plugins/compile_commands_json_db' )
  end

  def existing(content)
    allow(@file_wrapper).to receive(:exist?).with(database_path).and_return(true)
    allow(@file_wrapper).to receive(:read).with(database_path).and_return(content)
  end

  def compile(source, object: source.sub(/\.c\z/, '.o'), command: "gcc -c #{source} -o #{object}", compile_source: nil)
    plugin.post_compile_execute( source: source, object: object, shell_command: command, compile_source: compile_source )
  end

  # The database as written at the end of the build
  def written
    database = nil
    allow(@file_wrapper).to receive(:write).with(database_path, anything) { |_, content| database = JSON.parse(content) }
    plugin.post_build(0)
    database
  end

  it 'records a compile as directory, file, command, and output' do
    compile('src/adder.c')

    expect(written).to eq([{
      'directory' => Dir.pwd,
      'file'      => 'src/adder.c',
      'command'   => 'gcc -c src/adder.c -o src/adder.o',
      'output'    => 'src/adder.o'
    }])
  end

  it 'keeps one entry per source file, the last compile replacing earlier ones' do
    compile('src/adder.c', command: 'gcc -DFIRST -c src/adder.c')
    compile('src/sensor.c')
    compile('src/adder.c', command: 'gcc -DSECOND -c src/adder.c')

    database = written
    expect(database.map { |entry| entry['file'] }).to eq(['src/adder.c', 'src/sensor.c'])
    expect(database.first['command']).to eq('gcc -DSECOND -c src/adder.c')
  end

  # A delta build compiles only what changed, so entries from earlier builds carry over
  it 'starts from the database an earlier build wrote' do
    existing( JSON.generate([{ 'directory' => '/p', 'file' => 'src/old.c', 'command' => 'gcc -c src/old.c', 'output' => 'old.o' }]) )
    compile('src/adder.c')

    expect(written.map { |entry| entry['file'] }).to eq(['src/old.c', 'src/adder.c'])
  end

  # The compiler ran on an isolated copy, but the database must describe the real file
  it 'names the original source in the command of a compile made from an isolated copy' do
    compile('src/adder.c', command: 'gcc -c build/test/out/tmp1/adder.c -o adder.o', compile_source: 'build/test/out/tmp1/adder.c')

    expect(written.first['command']).to eq('gcc -c src/adder.c -o adder.o')
  end

  describe 'writing the database' do
    it 'writes nothing while compiles are underway' do
      expect(@file_wrapper).to_not receive(:write)
      compile('src/adder.c')
      compile('src/sensor.c')
    end

    it 'writes once when the build ends' do
      compile('src/adder.c')
      compile('src/sensor.c')

      expect(@file_wrapper).to receive(:write).with(database_path, anything).once
      plugin.post_build(0)
    end

    it 'writes what compiled when the build fails' do
      compile('src/adder.c')

      expect(@file_wrapper).to receive(:write).with(database_path, anything).once
      plugin.post_error(0)
    end

    it 'leaves the database untouched when nothing compiled' do
      expect(@file_wrapper).to_not receive(:write)
      plugin.post_build(0)
    end
  end

  # A damaged database must not fail every later build
  describe 'an unreadable existing database' do
    it 'starts fresh from a file that is not JSON' do
      existing('{ "truncated": ')
      compile('src/adder.c')

      expect(written.map { |entry| entry['file'] }).to eq(['src/adder.c'])
    end

    it 'starts fresh from JSON that is not a list of entries' do
      existing('{}')
      compile('src/adder.c')

      expect(written.map { |entry| entry['file'] }).to eq(['src/adder.c'])
    end

    it 'logs that it is starting fresh' do
      existing('not json')
      expect(@loginator).to receive(:log).with(/compile_commands\.json/, Verbosity::COMPLAIN, LogLabels::NOTICE)
      plugin
    end
  end
end
