# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for the JSON compilation database plugin against real files.
#
# Whether the database a build leaves on disk parses, and whether the next build picks it
# up, are filesystem facts. A real FileWrapper runs here against a real temp artifacts
# directory. The unit spec at spec/units/plugins/compile_commands_json_db_spec.rb owns
# every decision observable through a doubled file layer.

require 'spec_helper'
require 'json'
require 'tmpdir'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/file_wrapper'

$: << File.expand_path('../../../plugins/compile_commands_json_db/lib', __FILE__)
require 'compile_commands_json_db'

describe 'CompileCommandsJsonDb (integration)' do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @artifacts = dir
      example.run
    end
  end

  before(:each) do
    stub_const('PROJECT_BUILD_ARTIFACTS_ROOT', @artifacts)

    @loginator   = double('loginator', log: nil)
    verbosinator = double('verbosinator', should_output?: false)
    @objects     = { file_wrapper: FileWrapper.new( { loginator: @loginator, verbosinator: verbosinator } ), loginator: @loginator }
  end

  let(:database_path) { File.join( @artifacts, 'compile_commands.json' ) }

  # One build: a fresh plugin, the given compiles, then the end of the build
  def build(*sources)
    plugin = CompileCommandsJsonDb.new( @objects, 'compile_commands_json_db', '/plugins/compile_commands_json_db' )
    sources.each do |source|
      plugin.post_compile_execute( source: source, object: "#{source}.o", shell_command: "gcc -c #{source}" )
    end
    plugin.post_build(0)
  end

  it 'leaves a JSON array of compile entries on disk' do
    build('src/adder.c')

    database = JSON.parse( File.read( database_path ) )
    expect(database).to be_an(Array)
    expect(database.first).to include('file' => 'src/adder.c', 'command' => 'gcc -c src/adder.c')
  end

  it "carries one build's entries into the next" do
    build('src/adder.c')
    build('src/sensor.c')

    files = JSON.parse( File.read( database_path ) ).map { |entry| entry['file'] }
    expect(files).to eq(['src/adder.c', 'src/sensor.c'])
  end

  it 'recovers from a corrupt database left by an earlier build' do
    File.write( database_path, '[{"file": "src/old.c", ' )

    expect { build('src/adder.c') }.to_not raise_error

    files = JSON.parse( File.read( database_path ) ).map { |entry| entry['file'] }
    expect(files).to eq(['src/adder.c'])
  end
end
