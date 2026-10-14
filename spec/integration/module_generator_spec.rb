# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The Module Generator plugin end to end, below the CLI: its rake tasks, the plugin,
# Unity's module generator, CMock's skeleton generator, and Ceedling's path matcher all
# run for real against files in a temporary project.
#
# Each example invokes the plugin's own rake tasks with the arguments a user types
# between the brackets of `ceedling module:create[...]`, so argument parsing is covered
# along with generation.

require 'spec_helper'
require 'rake'
require 'tmpdir'
require 'stringio'
require 'yaml'  # a Ceedling build always has YAML loaded
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'
require 'ceedling/file_finder_helper'
require 'ceedling/file_wrapper'

PLUGIN_ROOT = File.expand_path( '../../plugins/module_generator', __dir__ )

[File.join( PLUGIN_ROOT, 'lib' ),
 File.expand_path( '../../vendor/unity/auto', __dir__ ),
 File.expand_path( '../../vendor/cmock/lib', __dir__ )].each { |path| $LOAD_PATH.unshift( path ) unless $LOAD_PATH.include?( path ) }

require 'module_generator'

describe 'Module Generator plugin (integration)' do

  # The project configuration a build would hand the plugin, with the plugin's own
  # defaults (config/module_generator.yml) already merged
  def project_config(source:, include: [], test:, **module_generator)
    config = {
      collection_paths_source:  source,
      collection_paths_include: include,
      collection_paths_test:    test,
      project_test_file_prefix: 'test_',
      cmock_mock_prefix:        'mock_',
      module_generator_boilerplates: { src: '', inc: '', tst: '' }
    }
    module_generator.each { |key, value| config[:"module_generator_#{key}"] = value }
    return config
  end

  def plugin_for(config)
    loginator = double( 'loginator', log: nil )
    objects   = {
      configurator:       double( 'configurator', project_config_hash: config, get_cmock_config: { mock_prefix: config[:cmock_mock_prefix] } ),
      file_finder_helper: FileFinderHelper.new( { loginator: loginator } ),
      file_wrapper:       FileWrapper.new( { loginator: loginator, verbosinator: double( 'verbosinator' ) } ),
      loginator:          loginator
    }
    return ModuleGenerator.new( objects, 'module_generator', PLUGIN_ROOT )
  end

  # Invokes one of the plugin's rake tasks in a fresh Rake application, returning what
  # it printed
  def run_task(config, task, *args)
    previous = Rake.application
    Rake.application = Rake::Application.new
    load File.join( PLUGIN_ROOT, 'module_generator.rake' )
    TOPLEVEL_BINDING.receiver.instance_variable_set( :@ceedling, { module_generator: plugin_for( config ) } )

    output, $stdout = $stdout, StringIO.new
    begin
      Rake::Task["module:#{task}"].invoke( *args )
      return $stdout.string
    ensure
      $stdout = output
      Rake.application = previous
    end
  end

  def capture_stdout
    output, $stdout = $stdout, StringIO.new
    yield
  ensure
    $stdout = output
  end

  def in_project(*dirs)
    Dir.mktmpdir( 'module_generator' ) do |root|
      Dir.chdir( root ) do
        dirs.each { |dir| FileUtils.mkdir_p( dir ) }
        yield
      end
    end
  end

  def flat_config(**module_generator)
    return project_config( source: ['src'], include: ['inc'], test: ['test'], **module_generator )
  end

  def files
    return Dir.glob( '**/*' ).select { |path| File.file?( path ) }.sort
  end

  describe 'module:create' do
    it 'creates a source, header, and test file in the first path of each list' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config, 'create', 'a_file' )

        expect(files).to eq( ['inc/a_file.h', 'src/a_file.c', 'test/test_a_file.c'] )
        expect(File.read( 'src/a_file.c' )).to include( '#include "a_file.h"' )
        expect(File.read( 'inc/a_file.h' )).to include( '#ifndef A_FILE_H' )
        expect(File.read( 'test/test_a_file.c' )).to include( '#ifdef TEST', 'void test_a_file_NeedToImplement(void)' )
      end
    end

    it 'places files in the paths a hint matches' do
      config = project_config( source: ['s', 'sub/s'], include: ['i', 'sub/i'], test: ['t', 'sub/t'] )

      in_project( 's', 'sub/s', 'i', 'sub/i', 't', 'sub/t' ) do
        run_task( config, 'create', 'sub:b_file' )

        expect(files).to eq( ['sub/i/b_file.h', 'sub/s/b_file.c', 'sub/t/test_b_file.c'] )
      end
    end

    it 'places files in subdirectories of a path a hint matches' do
      config = project_config( source: ['src', 'src/lab'], include: ['inc', 'inc/lab'], test: ['test', 'test/lab'] )

      in_project( 'src/lab', 'inc/lab', 'test/lab' ) do
        run_task( config, 'create', 'lab:SecretLair' )

        expect(files).to eq( ['inc/lab/SecretLair.h', 'src/lab/SecretLair.c', 'test/lab/test_SecretLair.c'] )
      end
    end

    it 'falls back to the first path of a list the hint matches nothing in' do
      config = project_config( source: ['src', 'src/lab'], include: ['inc', 'inc/lab'], test: ['test'] )

      in_project( 'src/lab', 'inc/lab', 'test' ) do
        run_task( config, 'create', 'lab:SecretLair' )

        expect(files).to eq( ['inc/lab/SecretLair.h', 'src/lab/SecretLair.c', 'test/test_SecretLair.c'] )
      end
    end

    it 'creates a subdirectory a slash names' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config, 'create', 'newlab/SecretLair' )

        expect(files).to eq( ['inc/newlab/SecretLair.h', 'src/newlab/SecretLair.c', 'test/newlab/test_SecretLair.c'] )
      end
    end

    it 'refuses a hint that matches no path and creates nothing' do
      in_project( 'src', 'inc', 'test' ) do
        expect { run_task( flat_config, 'create', 'bad:stubby' ) }.to raise_error( CeedlingException, /hint `bad` matches no source, include, or test path/ )
        expect(files).to be_empty
      end
    end

    it 'creates a file for each part of a pattern' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config, 'create', 'SecretLair', 'mch' )

        expect(files.size).to eq( 9 )
        expect(files).to include( 'src/SecretLair_Model.c', 'inc/SecretLair_Conductor.h', 'test/test_SecretLair_Hardware.c' )
        expect(File.read( 'src/SecretLair_Conductor.c' )).to include( '#include "SecretLair_Model.h"', '#include "SecretLair_Hardware.h"' )
        expect(File.read( 'test/test_SecretLair_Conductor.c' )).to include( '#include "mock_SecretLair_Model.h"' )
      end
    end

    it 'creates only a test file for a name carrying the test prefix' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config, 'create', 'test_widget' )

        expect(files).to eq( ['test/test_widget.c'] )
      end
    end

    it 'writes boilerplates, naming each file where a boilerplate asks' do
      config = flat_config( boilerplates: { src: '/* %1$s source */', inc: '/* header */', tst: '/* %1$s test */' } )

      in_project( 'src', 'inc', 'test' ) do
        run_task( config, 'create', 'a_file' )

        expect(File.read( 'src/a_file.c' )).to start_with( "/* a_file source */\n" )
        expect(File.read( 'inc/a_file.h' )).to start_with( "/* header */\n" )
        expect(File.read( 'test/test_a_file.c' )).to start_with( "/* a_file test */\n" )
      end
    end

    it 'reads boilerplates from files' do
      in_project( 'src', 'inc', 'test' ) do
        File.write( 'src_boilerplate.txt', '/* from a file */' )
        config = flat_config( boilerplate_files: { src: 'src_boilerplate.txt' } )

        run_task( config, 'create', 'a_file' )

        expect(File.read( 'src/a_file.c' )).to start_with( "/* from a file */\n" )
      end
    end

    it 'adds configured includes to each kind of file' do
      config = flat_config( includes: { src: ['board.h'], inc: ['types.h'], tst: ['defs.h'] } )

      in_project( 'src', 'inc', 'test' ) do
        run_task( config, 'create', 'a_file' )

        expect(File.read( 'src/a_file.c' )).to include( '#include "board.h"' )
        expect(File.read( 'inc/a_file.h' )).to include( '#include "types.h"' )
        expect(File.read( 'test/test_a_file.c' )).to include( '#include "defs.h"' )
      end
    end

    it 'guards a test file with a configured test define' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config( test_define: 'CEEDLING_TEST' ), 'create', 'a_file' )

        expect(File.read( 'test/test_a_file.c' )).to include( '#ifdef CEEDLING_TEST', '#endif // CEEDLING_TEST' )
      end
    end

    it 'applies a :snake naming convention' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config( naming: :snake ), 'create', 'MadScience' )

        expect(files).to eq( ['inc/mad_science.h', 'src/mad_science.c', 'test/test_mad_science.c'] )
      end
    end

    it 'applies :bumpy and :camel as the documentation describes them' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config( naming: :bumpy ), 'create', 'mad_science' )
        run_task( flat_config( naming: :camel ), 'create', 'evil_genius' )

        expect(files).to include( 'src/MadScience.c', 'src/evilGenius.c' )
      end
    end

    it 'matches several ordered hints to nested folders' do
      config = project_config( source: ['src', 'my/lab/secret'], include: ['inc', 'my/lab/secret'], test: ['test', 'my/lab/secret'] )

      in_project( 'src', 'inc', 'test', 'my/lab/secret' ) do
        run_task( config, 'create', 'lab:secret:lair' )

        expect(files).to include( 'my/lab/secret/lair.c' )
      end
    end

    it 'places headers with the matched source when no include paths are listed' do
      config = project_config( source: ['lab/src', 'lair/src'], test: ['lab/test', 'lair/test'] )

      in_project( 'lab/src', 'lair/src', 'lab/test', 'lair/test' ) do
        run_task( config, 'create', 'lab:SecretLair' )

        expect(files).to eq( ['lab/src/SecretLair.c', 'lab/src/SecretLair.h', 'lab/test/test_SecretLair.c'] )
      end
    end

    it 'applies a hint only to the module it precedes' do
      config = project_config( source: ['src', 'src/lab'], include: ['inc', 'inc/lab'], test: ['test', 'test/lab'] )

      in_project( 'src/lab', 'inc/lab', 'test/lab' ) do
        run_task( config, 'create', 'lab:first', 'second' )

        expect(files).to include( 'src/lab/first.c', 'src/second.c' )
      end
    end

    it 'treats a name that only begins with the letters of the test prefix as a module' do
      in_project( 'src', 'inc', 'test' ) do
        run_task( flat_config, 'create', 'testimony' )

        expect(files).to eq( ['inc/testimony.h', 'src/testimony.c', 'test/test_testimony.c'] )
      end
    end
  end

  describe 'module:destroy' do
    it 'removes the files a create made' do
      config = project_config( source: ['s', 'sub/s'], include: ['i', 'sub/i'], test: ['t', 'sub/t'] )

      in_project( 's', 'sub/s', 'i', 'sub/i', 't', 'sub/t' ) do
        run_task( config, 'create', 'sub:b_file' )
        run_task( config, 'destroy', 'sub:b_file' )

        expect(files).to be_empty
      end
    end
  end

  describe 'module:stub' do
    let(:header_v1) { "void shorty(void);\n" }
    let(:header_v2) { "void shorty(void);\nvoid shrimpy(int a);\nint tiny(void);\n" }

    it 'creates a source file with a stub for each declared function, then adds new ones' do
      config = project_config( source: ['s', 's/rev'], include: ['i', 'i/rev'], test: ['t', 't/rev'] )

      in_project( 's/rev', 'i/rev', 't/rev' ) do
        File.write( 'i/rev/stubby.h', header_v1 )
        run_task( config, 'stub', 'rev:stubby' )
        expect(File.read( 's/rev/stubby.c' )).to include( 'void shorty(void)' )

        File.write( 'i/rev/stubby.h', header_v2 )
        run_task( config, 'stub', 'rev:stubby' )
        expect(File.read( 's/rev/stubby.c' )).to include( 'void shorty(void)', 'void shrimpy(int a)', 'int tiny(void)' )
      end
    end

    it 'reads a header from a subdirectory a slash names and writes the stub beside it' do
      in_project( 's/rev', 'i/rev', 't' ) do
        File.write( 'i/rev/stubby.h', header_v1 )
        run_task( project_config( source: ['s'], include: ['i'], test: ['t'] ), 'stub', 'rev/stubby' )

        expect(File.read( 's/rev/stubby.c' )).to include( 'void shorty(void)' )
      end
    end

    it 'parses the header with the project CMock settings' do
      config = project_config( source: ['s'], include: ['i'], test: ['t'] )

      in_project( 's', 'i', 't' ) do
        File.write( 'i/stubby.h', "void SPECIAL_ATTR shorty(void);\n" )
        plugin = plugin_for( config )
        allow(plugin.instance_variable_get( :@ceedling )[:configurator]).to receive(:get_cmock_config).and_return( strippables: ['SPECIAL_ATTR'] )

        capture_stdout { plugin.stub( ModuleGeneratorRequest.new( name: 'stubby' ) ) }

        expect(File.read( 's/stubby.c' )).to include( 'void shorty(void)' )
        expect(File.read( 's/stubby.c' )).not_to include( 'SPECIAL_ATTR' )
      end
    end

    it 'prints no configuration dump' do
      in_project( 's', 'i', 't' ) do
        File.write( 'i/stubby.h', header_v1 )
        output = run_task( project_config( source: ['s'], include: ['i'], test: ['t'] ), 'stub', 'stubby' )

        expect(output).not_to include( ':path_src:' )
      end
    end

    it 'hands CMock options it accepts without warning' do
      in_project( 's', 'i', 't' ) do
        File.write( 'i/stubby.h', header_v1 )
        output = run_task( project_config( source: ['s'], include: ['i'], test: ['t'] ), 'stub', 'stubby' )

        expect(output).not_to include( 'WARNING' )
      end
    end
  end

end
