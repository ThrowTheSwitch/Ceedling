# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/exceptions'
require 'ceedling/constants'
require 'module_generator_request'
require 'module_generator_options'
require 'module_generator_project'
require 'module_generator_test_file'

# Creates, destroys, stubs, and tests modules for the `module:` tasks. Unity's module
# generator, through ModuleGeneratorUnity, writes and removes source, header, and test
# files, and CMock's skeleton generator writes a source file of stubs from a header. This
# plugin hands each one the options ModuleGeneratorOptions builds for a request from the
# project configuration.
class ModuleGenerator < Plugin

  # The configured test file prefix, which marks a module argument as a test file
  def test_prefix
    return @ceedling[:configurator].project_config_hash[:project_test_file_prefix]
  end

  def create(request)
    generator = unity_generator( request )
    planned   = generator.files_to_operate_on( request.name )
    warn_same_named( planned )
    generator.generate( request.name )
    warn_undefined_test_define( planned.reject { |file| file[:test_define].nil? }.map { |file| file[:path].to_s } )
  end

  def destroy(request)
    unity_generator( request ).destroy( request.name )
  end

  def stub(request)
    require 'cmock'

    stub = options.stub( request )
    CMock.new( stub[:cmock] ).setup_skeletons( stub[:header] )
  end

  # Writes a test file with an ignored test for each function the module's header
  # declares, or adds tests for newly declared functions to an existing one
  def test(request)
    require 'cmock'

    test      = options.test( request )
    functions = header_functions( test )
    existing  = @ceedling[:file_wrapper].exist?( test[:path] ) ? @ceedling[:file_wrapper].read( test[:path] ) : nil
    result    = ModuleGeneratorTestFile.new( **test[:file] ).render( functions, existing: existing )

    write_test( test[:path], result, existing.nil? )
    warn_undefined_test_define( [test[:path]] )
  end

  private

  def header_functions(test)
    source = @ceedling[:file_wrapper].read( test[:header] )
    parsed = CMockHeaderParser.new( CMockConfig.new( test[:cmock] ) ).parse( test[:file][:module_name], source )

    return parsed[:functions].map { |function| function[:name] }
  rescue SystemCallError
    raise CeedlingException.new( "Module header `#{test[:header]}` does not exist." )
  end

  def write_test(path, result, created)
    return @ceedling[:loginator].log( "No new functions to test in #{path}" ) if !created and result.added.empty?

    @ceedling[:file_wrapper].mkdir( File.dirname( path ) )
    @ceedling[:file_wrapper].write( path, result.content )
    @ceedling[:loginator].log( "#{created ? 'Created' : 'Updated'} #{path} with #{result.added.size} test(s)" )
  end

  def unity_generator(request)
    require 'module_generator_unity'

    return ModuleGeneratorUnity.new( options.unity( request ) )
  end

  # Built once per run from configuration that does not change during it
  def options
    return @options if @options

    warn_update_svn
    @options = ModuleGeneratorOptions.new(
      config:             @ceedling[:configurator].project_config_hash,
      cmock_config:       @ceedling[:configurator].get_cmock_config,
      path_finder:        method( :find_path ),
      boilerplate_reader: method( :read_boilerplate )
    )
  end

  def project
    return @project ||= ModuleGeneratorProject.new(
      @ceedling[:configurator].project_config_hash,
      test_defines: ->( path ) { @ceedling[:defineinator].defines( subkey: :test, filepath: path ) }
    )
  end

  # Subversion support is gone, so a configured :update_svn is noted, once with the
  # options, and ignored
  def warn_update_svn
    return unless @ceedling[:configurator].project_config_hash.key?( :module_generator_update_svn )

    @ceedling[:loginator].log(
      'Module Generator :update_svn is deprecated and ignored. Add generated files to source control with your own tools.',
      Verbosity::COMPLAIN, LogLabels::WARNING
    )
  end

  # A same-named file elsewhere is allowed, but worth knowing about before it exists
  def warn_same_named(files)
    project.same_named( files.map { |file| file[:path].to_s } ).each do |planned, existing|
      @ceedling[:loginator].log(
        "Module file `#{planned}` shares its name with #{existing.map { |path| "`#{path}`" }.join( ', ' )}.",
        Verbosity::COMPLAIN, LogLabels::WARNING
      )
    end
  end

  # A test file whose build lacks its guard symbol compiles to nothing. Per-test matchers
  # can give each test file different defines, so each is checked on its own.
  def warn_undefined_test_define(test_paths)
    define = options.test_define

    test_paths.reject { |path| project.test_defined?( define, path ) }.each do |path|
      @ceedling[:loginator].log(
        "Generated test `#{path}` is wrapped in `##{options.test_guard} #{define}`, but its build does not " \
        "define #{define}. Add it under :defines ↳ :test, or the test compiles to nothing.",
        Verbosity::COMPLAIN, LogLabels::WARNING
      )
    end
  end

  # The path in a list a hint matches best, or nil when it matches none
  def find_path(hint, paths)
    return @ceedling[:file_finder_helper].find_best_path_in_collection( hint, paths, :error, 'module' )
  rescue CeedlingException
    return nil
  end

  def read_boilerplate(path)
    return @ceedling[:file_wrapper].exist?( path ) ? @ceedling[:file_wrapper].read( path ) : nil
  end

end
