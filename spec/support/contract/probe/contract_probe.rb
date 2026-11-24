# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'ceedling/plugins/plugin'

# Observes one Ceedling process for the contract harness and writes what it saw as JSON.
#
# The runner enables it in every row's build and names the output file in
# CONTRACT_PROBE_OUT. It only reads. Build hooks give each compile, link, mock and runner
# as it happens. The pipeline state on TestInvoker gives each test's record at stage 5
# and at the end of each test build. Paths stay as Ceedling holds them, and the runner
# normalizes them afterward.
class ContractProbe < Plugin

  # Nesting past this depth is cut, so a record that reaches a large object stays small
  MAX_DEPTH = 8

  def setup
    @lock   = Mutex.new
    @output = ENV['CONTRACT_PROBE_OUT']
    @record = {
      'cwd'        => Dir.pwd,
      'builds'     => [],
      'stage5'     => {},
      'compiles'   => [],
      'links'      => [],
      'mocks'      => [],
      'runners'    => [],
      'isolations' => []
    }

    # A build that raises before post_build still leaves its record
    at_exit { write }
  end

  def pre_test(test)
    testable = find_testable( test )
    return if testable.nil?

    snapshot = {
      'search_paths'      => Array( testable.search_paths ).dup,
      'mock_search_paths' => Array( testable.mock_search_paths ).dup
    }
    @lock.synchronize { @record['stage5'][testable.name.to_s] = snapshot }
  end

  def pre_compile_execute(arg_hash)
    entry = {
      'context'        => arg_hash[:context].to_s,
      'module_name'    => arg_hash[:module_name].to_s,
      'source'         => arg_hash[:source].to_s,
      'compile_source' => arg_hash[:compile_source]&.to_s,
      'object'         => arg_hash[:object].to_s,
      'search_paths'   => Array( arg_hash[:search_paths] ).map( &:to_s ),
      'dependencies'   => arg_hash[:dependencies].to_s
    }
    @lock.synchronize { @record['compiles'] << entry }
    note_isolations()
  end

  def post_compile_execute(arg_hash)
    note_failure( 'compiles', arg_hash, 'object' )
  end

  def pre_link_execute(arg_hash)
    entry = {
      'context'    => arg_hash[:context].to_s,
      'executable' => arg_hash[:executable].to_s,
      'objects'    => Array( arg_hash[:objects] ).map( &:to_s ),
      'libraries'  => Array( arg_hash[:libraries] ).map( &:to_s ),
      'libpaths'   => Array( arg_hash[:libpaths] ).map( &:to_s )
    }
    @lock.synchronize { @record['links'] << entry }
  end

  def post_link_execute(arg_hash)
    note_failure( 'links', arg_hash, 'executable' )
  end

  def pre_mock_generate(arg_hash)
    entry = {
      'context'     => arg_hash[:context].to_s,
      'test'        => arg_hash[:test].to_s,
      'header_file' => arg_hash[:header_file].to_s,
      'output_path' => arg_hash[:output_path].to_s
    }
    @lock.synchronize { @record['mocks'] << entry }
  end

  def pre_runner_generate(arg_hash)
    entry = {
      'context'     => arg_hash[:context].to_s,
      'test_file'   => arg_hash[:test_file].to_s,
      'input_file'  => arg_hash[:input_file].to_s,
      'runner_file' => arg_hash[:runner_file].to_s
    }
    @lock.synchronize { @record['runners'] << entry }
  end

  def post_test_build(context, _timestamp)
    state     = test_invoker.state
    testables = {}
    unless state.nil?
      state.testables.each { |name, testable| testables[name.to_s] = plain( testable ) }
    end

    @lock.synchronize { @record['builds'] << { 'context' => context.to_s, 'testables' => testables } }
    write
  end

  def post_build(_timestamp)
    write
  end

  private

  def test_invoker
    return @ceedling[:test_invoker]
  end

  def find_testable(filepath)
    state = test_invoker.state
    return nil if state.nil?

    return state.testables.values.find { |testable| testable.filepath.to_s == filepath.to_s }
  end

  # Header isolation lasts only through stage 15, so each compile notes any it sees
  def note_isolations
    state = test_invoker.state
    return if state.nil?

    state.testables.each_value do |testable|
      isolation = testable.header_isolation
      next if isolation.nil?

      entry = { 'test' => testable.name.to_s, 'dir' => isolation.dir.to_s, 'copies' => plain( isolation.copies ) }
      @lock.synchronize { @record['isolations'] << entry unless @record['isolations'].include?( entry ) }
    end
  end

  # Marks the hook's entry with the first line of a failed tool's output
  def note_failure(kind, arg_hash, key)
    result = arg_hash[:shell_result]
    return unless result.is_a?( Hash ) and !result[:exit_code].nil? and result[:exit_code] != 0

    @lock.synchronize do
      entry = @record[kind].reverse.find { |item| item[key] == arg_hash[key.to_sym].to_s }
      entry['failure'] = result[:output].to_s.lines.map( &:chomp ) unless entry.nil?
    end
  end

  # A JSON-ready copy of a pipeline record
  def plain(value, depth = 0)
    return nil if depth > MAX_DEPTH

    case value
    when nil, true, false, Numeric, String then value
    when Symbol then value.to_s
    when Array  then value.map { |item| plain( item, depth + 1 ) }
    when Hash   then value.each_with_object( {} ) { |(key, item), hash| hash[key.to_s] = plain( item, depth + 1 ) }
    when Struct then value.each_pair.each_with_object( {} ) { |(key, item), hash| hash[key.to_s] = plain( item, depth + 1 ) }
    else
      value.instance_variables.each_with_object( { 'class' => value.class.name } ) do |name, hash|
        hash[name.to_s.delete( '@' )] = plain( value.instance_variable_get( name ), depth + 1 )
      end
    end
  end

  def write
    return if @output.nil? or @output.empty?

    text = @lock.synchronize { JSON.pretty_generate( @record ) }
    File.write( @output, text )
  end

end
