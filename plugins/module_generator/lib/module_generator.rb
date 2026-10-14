# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/exceptions'
require 'module_generator_request'
require 'module_generator_options'

# Creates, destroys, and stubs modules for the `module:` tasks. Unity's module
# generator writes and removes source, header, and test files, and CMock's skeleton
# generator writes a source file of stubs from a header. This plugin hands each one the
# options ModuleGeneratorOptions builds for a request from the project configuration.
class ModuleGenerator < Plugin

  # The configured test file prefix, which marks a module argument as a test file
  def test_prefix
    return @ceedling[:configurator].project_config_hash[:project_test_file_prefix]
  end

  def create(request)
    unity_generator( request ).generate( request.name )
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
    require 'generate_module'

    return UnityModuleGenerator.new( options.unity( request ) )
  end

  def options
    return ModuleGeneratorOptions.new(
      config:             @ceedling[:configurator].project_config_hash,
      cmock_config:       @ceedling[:configurator].get_cmock_config,
      path_finder:        method( :find_path ),
      boilerplate_reader: method( :read_boilerplate )
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
