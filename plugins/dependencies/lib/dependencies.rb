# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'pathname'
require 'dependency_spec'
require 'dependency_commands'
require 'dependency_environment'

DEPENDENCIES_ROOT_NAME = 'dependencies'
DEPENDENCIES_TASK_ROOT = DEPENDENCIES_ROOT_NAME + ':'
DEPENDENCIES_SYM       = DEPENDENCIES_ROOT_NAME.to_sym

class Dependencies < Plugin

  attr_reader :specs

  def setup()
    @specs  = DependencySpec.build_all( DEPENDENCIES_DEPS )
    @lookup = {}

    # A dependency is found by its name, its task name, or any artifact it produces
    @specs.each do |spec|
      keys = [spec.name, spec.task_name] + spec.static_libraries + spec.dynamic_libraries +
             spec.include_directories( path_collector ) + spec.include_files + spec.source_paths
      keys.each { |key| @lookup[key] = spec }
      validate_fetch_tools( spec )
      environment_for( spec )
    end
  end

  def config()
    updates = {
      :collection_paths_include => COLLECTION_PATHS_INCLUDE,
      :collection_all_headers => COLLECTION_ALL_HEADERS,
    }

    @ceedling[DEPENDENCIES_SYM].specs.each do |spec|
      updates[:collection_paths_include].concat( spec.include_directories( path_collector ) )
      updates[:collection_all_headers].concat( spec.include_files )
    end

    updates
  end

  # Globbed include entries expand against the disk
  def path_collector
    return ->( glob ) { @ceedling[:file_path_collection_utils].collect_paths( [glob] ) }
  end

  def spec_for(key)
    return @lookup[key] || raise( CeedlingException.new( "Could not find dependency '#{key}'" ) )
  end

  # The commands that fetch and build dependencies, from the plugin's configured tools
  def commands
    tools = { zip: TOOLS_DEPS_ZIP, tar_gzip: TOOLS_DEPS_TARGZIP, git_clone: TOOLS_DEPS_GIT_CLONE,
              git_checkout: TOOLS_DEPS_GIT_CHECKOUT, subversion: TOOLS_DEPS_SUBVERSION }
    builder = ->( tool, *args ) { @ceedling[:tool_executor].build_command_line( tool, [], *args ) }

    return @commands ||= DependencyCommands.new( tools: tools, builder: builder )
  end

  # Fetches, then builds, a dependency inside its environment
  def make_if_required(lib_path)
    spec = spec_for( lib_path )
    environment_for( spec ).apply do
      fetch_dependency( spec )
      build_dependency( spec )
    end
  end

  def fetch_if_required(lib_path)
    spec = spec_for( lib_path )
    environment_for( spec ).apply { fetch_dependency( spec ) }
  end

  def build_if_required(lib_path)
    spec = spec_for( lib_path )
    environment_for( spec ).apply { build_dependency( spec ) }
  end

  # A dependency's :environment, in effect only while its own commands run. Named apart
  # from Plugin#environment, which Ceedling reads when it loads a plugin.
  def environment_for(spec)
    return DependencyEnvironment.new( spec.environment, dependency: spec.name )
  end

  def fetch_dependency(spec)
    if spec.fetch_method.nil?
      @ceedling[:loginator].log("No fetch method for dependency '#{spec.name}'", Verbosity::COMPLAIN)
      return
    end

    unless (directory(spec.source_path))
      @ceedling[:loginator].log("Path #{spec.source_path} is required", Verbosity::COMPLAIN)
      return
    end

    FileUtils.mkdir_p(spec.fetch_path) unless File.exist?(spec.fetch_path)

    steps = commands.fetch( spec )

    # Perform the actual fetching
    @ceedling[:loginator].log("Fetching dependency #{spec.name}...", Verbosity::NORMAL)
    Dir.chdir(spec.fetch_path) do
      steps.each do |step|
        @ceedling[:tool_executor].exec( step )
      end
    end
  end

  def build_dependency(spec)
    if spec.build_steps.empty?
      @ceedling[:loginator].log("Nothing to build for dependency #{spec.name}", Verbosity::NORMAL)
      return
    end

    FileUtils.mkdir_p(spec.source_path) unless File.exist?(spec.source_path)
    FileUtils.mkdir_p(spec.artifact_path) unless File.exist?(spec.artifact_path)

    # Perform the build
    @ceedling[:loginator].log("Building dependency #{spec.name}...", Verbosity::NORMAL)
    Dir.chdir(spec.source_path) do
      commands.build( spec ).each do |step|
        if step.is_a?( Symbol )
          exec_dependency_builtin_command(step, spec)
        else
          @ceedling[:tool_executor].exec( step )
        end
      end
    end
  end

  def clean_if_required(lib_path)
    spec = spec_for( lib_path )

    # We don't clean anything unless we know how to fetch a new copy
    if spec.fetch_method.nil?
      @ceedling[:loginator].log("Nothing to clean for dependency #{spec.name}", Verbosity::NORMAL)
      return
    end

    # We only need to clean the artifacts if the source isn't being fetched
    artifacts_only = (spec.fetch_method == :none)

    # Perform the actual Cleaning
    @ceedling[:loginator].log("Cleaning dependency #{spec.name}...", Verbosity::NORMAL)
    spec.working_paths( artifacts_only: artifacts_only ).each do |path|
      FileUtils.rm_rf(path) if File.directory?(path)
    end
  end

  def deploy_if_required(lib_path)
    spec = spec_for( lib_path )

    # We don't need to deploy anything if there isn't anything to deploy
    if spec.dynamic_libraries.empty?
      @ceedling[:loginator].log("Nothing to deploy for dependency #{spec.name}", Verbosity::NORMAL)
      return
    end

    # Perform the actual Deploying
    @ceedling[:loginator].log("Deploying dependency #{spec.name}...", Verbosity::NORMAL)
    FileUtils.cp( lib_path, File.dirname(PROJECT_RELEASE_BUILD_TARGET) )
  end

  def add_headers_and_sources()
    # Search for header file paths and files to add to our collections
    cfg = @ceedling[:configurator].project_config_hash

    @specs.each do |spec|
      spec.include_directories( path_collector ).each do |header|
        cfg[:collection_paths_include] << header
        cfg[:collection_paths_source_and_include] << header
        cfg[:collection_paths_test_support_source_include] << header
        cfg[:collection_paths_test_support_source_include_vendor] << header
        cfg[:collection_paths_release_toolchain_include] << header
      end

      spec.include_files.each do |header|
        cfg[:collection_all_headers] << header

        cfg[:files] ||= {}
        cfg[:files][:include] ||= []
        cfg[:files][:include] << header
      end

      spec.source_paths.each do |source|
        cfg[:collection_paths_source_and_include] << source
        cfg[:collection_paths_test_support_source_include] << source
        cfg[:collection_paths_test_support_source_include_vendor] << source
        cfg[:collection_paths_release_toolchain_include] << source
        Dir[ *EXTENSION_SOURCE.glob_patterns(source) ].each do |f|
          cfg[:collection_all_source] << f
        end
      end
    end
  end

  def exec_dependency_builtin_command(step, spec)
    case step
    when :build_lib # We are going to use our defined deps tools to build this library
      build_lib(spec)
    else
      raise CeedlingException.new( "No such build action as #{step.inspect} for dependency #{spec.name}" )
    end
  end

  def build_lib(spec)
    asm = []
    obj = []

    name = spec.name
    source_path = Pathname.new spec.source_path
    build_path = Pathname.new spec.build_path
    relative_build_path = begin
      build_path.relative_path_from(source_path)
    rescue StandardError
      build_path 
    end

    # Verify there is an artifact that we're building that makes sense
    libs = (spec.static_libraries + spec.static_libraries).map { |path| path.delete_prefix( "#{spec.artifact_path}/" ) }.uniq
    raise CeedlingException.new( "No library artifacts specified for dependency #{name}" ) if libs.empty?
    lib = libs[0]

    # Find all the source, header, and assembly files 
    src = Dir[ *EXTENSION_SOURCE.glob_patterns('./**') ]
    hdr = Dir[ *EXTENSION_HEADER.glob_patterns('./**') ].map{|f| File.dirname(f) }.uniq
    if (EXTENSION_ASSEMBLY && !EXTENSION_ASSEMBLY.empty?)
      asm = Dir[ *EXTENSION_ASSEMBLY.glob_patterns('./**') ]
    end

    # Do we have what we need to do this?
    raise CeedlingException.new( "Nothing to build" ) if (asm.empty? and src.empty?)
    raise CeedlingException.new( "No assembler specified for building dependency #{name}" ) unless (defined?(TOOLS_DEPS_ASSEMBLER) || asm.empty?)
    raise CeedlingException.new( "No compiler specified for building dependency #{name}" ) unless (defined?(TOOLS_DEPS_COMPILER) || src.empty?)
    raise CeedlingException.new( "No linker specified for building dependency #{name}" ) unless defined?(TOOLS_DEPS_LINKER)

    # Build all the source files
    src.each do |src_file|
      object_file = relative_build_path + File.basename(src_file).ext(EXTENSION_OBJECT.primary)
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_PATHS_DEPS, find_my_paths(src_file, spec))
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_DEFINES_DEPS, find_my_defines(src_file, spec))
      @ceedling[:generator].generate_object_file_c(
        tool:         TOOLS_DEPS_COMPILER,
        module_name:  File.basename(src_file).ext(),
        context:      DEPENDENCIES_SYM,
        source:       src_file,
        object:       object_file,
        search_paths: hdr,
        flags:        spec.flags,
        defines:      spec.defines,
        list:         @ceedling[:file_path_utils].form_release_build_list_filepath( File.basename(src_file, EXTENSION_OBJECT.primary) )
      )
      obj << object_file
    end 

    # Build all the assembly files
    asm.each do |src_file|
      object_file = relative_build_path + File.basename(src_file).ext(EXTENSION_OBJECT.primary)
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_PATHS_DEPS, find_my_paths(src_file, spec))
      @ceedling[DEPENDENCIES_SYM].replace_constant(:COLLECTION_DEFINES_DEPS, find_my_defines(src_file, spec))
      @ceedling[:generator].generate_object_file_asm(
        tool:        TOOLS_DEPS_ASSEMBLER,
        module_name: File.basename(src_file).ext(),
        context:     DEPENDENCIES_SYM,
        source:      src_file,
        object:      object_file
      )
      obj << object_file
    end

    # Link the library
    @ceedling[:generator].generate_executable_file(
      TOOLS_DEPS_LINKER,
      DEPENDENCIES_SYM,
      obj,
      [],
      relative_build_path+lib,
      @ceedling[:file_path_utils].form_test_build_map_filepath(spec.artifact_path,lib),
      spec.libraries,
      spec.libpaths
    )

    # Move the library to the specifed artifact folder
    unless spec.build_path == spec.artifact_path
      src = File.expand_path(lib)
      dst = File.expand_path(spec.artifact_path, Array.new(spec.build_path.split(/[\\\/]+/).length,"../").join()) + "/" + lib
      FileUtils.cp_r(src, dst)
    end
  end

  def find_my_paths( c_file, spec, file_type = :c )
    return spec.build_lib_search_paths
  end

  def find_my_defines( c_file, spec, file_type = :c )
    return spec.defines.compact.uniq
  end

  def replace_constant(constant, new_value)  
    Object.send(:remove_const, constant.to_sym) if (Object.const_defined? constant)  
    Object.const_set(constant, new_value)  
  end

  ### Private ###

  private

  # Unknown methods are already refused by DependencySpec
  def validate_fetch_tools(spec)
    case spec.fetch_method
    when :zip
      @ceedling[:tool_validator].validate( tool:TOOLS_DEPS_ZIP, boom:true )

    when :tar_gzip
      @ceedling[:tool_validator].validate( tool:TOOLS_DEPS_TARGZIP, boom:true )

    when :git
      @ceedling[:tool_validator].validate( tool:TOOLS_DEPS_GIT_CLONE, boom:true )
      @ceedling[:tool_validator].validate( tool:TOOLS_DEPS_GIT_CHECKOUT, boom: true )

    when :svn
      @ceedling[:tool_validator].validate( tool:TOOLS_DEPS_SUBVERSION, boom: true )

    end
  end

end


# end blocks always executed following rake run
END {
}
