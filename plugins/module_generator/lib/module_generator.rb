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

# Creates, destroys, and stubs modules for the `module:` tasks. Unity's module
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
    unity_generator( request ).generate( request.name )
    warn_undefined_test_define
  end

  def destroy(request)
    unity_generator( request ).destroy( request.name )
  end

  def stub(request)
    require 'cmock'

    stub = options.stub( request )
    CMock.new( stub[:cmock] ).setup_skeletons( stub[:header] )
  end

  private

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

  # Subversion support is gone, so a configured :update_svn is noted, once with the
  # options, and ignored
  def warn_update_svn
    return unless @ceedling[:configurator].project_config_hash.key?( :module_generator_update_svn )

    @ceedling[:loginator].log(
      'Module Generator :update_svn is deprecated and ignored. Add generated files to source control with your own tools.',
      Verbosity::COMPLAIN, LogLabels::WARNING
    )
  end

  # Noted once per run, since every generated test shares the same guard
  def warn_undefined_test_define
    define = options.undefined_test_define
    return if @test_define_warned or define.nil?

    @test_define_warned = true
    @ceedling[:loginator].log(
      "Generated tests are wrapped in `##{options.test_guard} #{define}`, but #{define} is not among the project's " \
      ":defines for tests. Add it under :defines ↳ :test, or the tests compile to nothing.",
      Verbosity::COMPLAIN, LogLabels::WARNING
    )
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
