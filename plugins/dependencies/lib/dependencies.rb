# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'dependency_spec'
require 'dependency_commands'
require 'dependency_environment'

DEPENDENCIES_ROOT_NAME = 'dependencies'
DEPENDENCIES_TASK_ROOT = DEPENDENCIES_ROOT_NAME + ':'
DEPENDENCIES_SYM       = DEPENDENCIES_ROOT_NAME.to_sym

# Fetches, builds, cleans, and deploys the third-party code a project depends on, and adds
# its headers, sources, and libraries to test and release builds.
#
# DependencySpec reads each configured dependency, DependencyCommands decides which tool
# commands fetch and build it, and DependencyEnvironment holds its environment variables
# while they run. This plugin carries those out. Files and directories go through the
# file wrapper and commands through the tool executor, and only a dependency's own
# commands run from inside its directories.
class Dependencies < Plugin

  attr_reader :specs

  def setup()
    @specs  = DependencySpec.build_all( DEPENDENCIES_DEPS )
    @lookup = {}

    # A dependency is found by its name, its task name, or any artifact it produces
    @specs.each do |spec|
      keys = [spec.name, spec.task_name] + spec.static_libraries + spec.dynamic_libraries + spec.executables +
             spec.include_directories( path_collector ) + spec.include_files + spec.source_paths
      keys.each { |key| @lookup[key] = spec }
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

  # Fetches, then builds, a dependency inside its environment
  def make_if_required(key)
    spec = spec_for( key )
    environment_for( spec ).apply do
      fetch_dependency( spec )
      build_dependency( spec )
    end
  end

  def fetch_if_required(key)
    spec = spec_for( key )
    environment_for( spec ).apply { fetch_dependency( spec ) }
  end

  # A fetched dependency's every working path goes, so a later fetch gets a fresh copy.
  # A dependency that is not fetched keeps its source, losing only its artifacts.
  def clean_if_required(key)
    spec = spec_for( key )

    if spec.fetch_method.nil?
      log( "Nothing to clean for dependency #{spec.name}" )
      return
    end

    log( "Cleaning dependency #{spec.name}..." )
    spec.working_paths( artifacts_only: spec.fetch_method == :none ).each do |path|
      @ceedling[:file_wrapper].rm_rf( path ) if @ceedling[:file_wrapper].directory?( path )
    end
  end

  # Copies every dynamic library and executable to the deploy path, by default beside the
  # release build, where they run from
  def deploy_if_required(key)
    spec      = spec_for( key )
    artifacts = spec.dynamic_libraries + spec.executables

    if artifacts.empty?
      log( "Nothing to deploy for dependency #{spec.name}" )
      return
    end

    log( "Deploying dependency #{spec.name}..." )
    destination = spec.deploy_path( File.dirname( PROJECT_RELEASE_BUILD_TARGET ) )
    @ceedling[:file_wrapper].mkdir( destination )

    # The deploy task builds missing artifacts first, so one still missing was never made
    artifacts.each do |artifact|
      unless @ceedling[:file_wrapper].exist?( artifact )
        raise CeedlingException.new(
          "Dependency `#{spec.name}` has no #{artifact} to deploy: its build did not produce it. Check its :build steps and :artifacts."
        )
      end

      @ceedling[:file_wrapper].cp( artifact, destination )
    end
  end

  # Library names and their directories, for test and release linking
  def link_libraries
    libraries = @specs.flat_map { |spec| spec.static_libraries + spec.dynamic_libraries }

    return {
      names: libraries.map { |library| File.basename( library, '.*' ).delete_prefix( 'lib' ) }.reject( &:empty? ).uniq,
      paths: libraries.map { |library| File.dirname( library ) }.reject( &:empty? ).uniq
    }
  end

  # Adds each dependency's include directories, headers, and sources to the collections
  # test and release builds search
  def add_headers_and_sources()
    cfg = @ceedling[:configurator].project_config_hash

    @specs.each do |spec|
      add_include_directories( cfg, spec.include_directories( path_collector ) )

      spec.include_files.each do |header|
        cfg[:collection_all_headers] << header
        ((cfg[:files] ||= {})[:include] ||= []) << header
      end

      spec.source_paths.each { |source| add_source_path( cfg, source ) }
    end
  end

  ### Private ###

  private

  def log(message, verbosity = Verbosity::NORMAL)
    @ceedling[:loginator].log( message, verbosity )
  end

  # A dependency's :environment, in effect only while its own commands run. Named apart
  # from Plugin#environment, which Ceedling reads when it loads a plugin.
  def environment_for(spec)
    return DependencyEnvironment.new( spec.environment, dependency: spec.name )
  end

  # The commands that fetch and build dependencies, from the plugin's configured tools
  def commands
    tools = { zip: TOOLS_DEPS_ZIP, tar_gzip: TOOLS_DEPS_TARGZIP, git_clone: TOOLS_DEPS_GIT_CLONE,
              git_checkout: TOOLS_DEPS_GIT_CHECKOUT, subversion: TOOLS_DEPS_SUBVERSION }
    builder = ->( tool, *args ) { @ceedling[:tool_executor].build_command_line( tool, [], *args ) }

    return @commands ||= DependencyCommands.new( tools: tools, builder: builder )
  end

  # The one place this plugin changes directory, around a dependency's own commands
  def in_directory(path, &block)
    Dir.chdir( path, &block )
  end

  # A fetch path that already holds files is taken as fetched, so fetching again, or
  # building after a fetch, leaves it alone. Cleaning the dependency allows a fresh fetch.
  def fetch_dependency(spec)
    if spec.fetch_method.nil?
      log( "No fetch method for dependency '#{spec.name}'", Verbosity::COMPLAIN )
      return
    end

    # A dependency fetched by :none is already where its paths say
    return if spec.fetch_method == :none

    path = spec.fetch_path
    if @ceedling[:file_wrapper].directory?( path ) and !@ceedling[:file_wrapper].directory_entries( path ).empty?
      log( "Dependency #{spec.name} is already fetched in #{path}. Clean it to fetch it again." )
      return
    end

    check_tools( *fetch_tools( spec.fetch_method ) )
    log( "Fetching dependency #{spec.name}..." )
    @ceedling[:file_wrapper].mkdir( path )
    steps = commands.fetch( spec )
    in_directory( path ) { steps.each { |step| @ceedling[:tool_executor].exec( step ) } }
  end

  # Build commands run from the source path; built-in steps use project paths
  def build_dependency(spec)
    if spec.build_steps.empty?
      log( "Nothing to build for dependency #{spec.name}" )
      return
    end

    [spec.source_path, spec.build_path, spec.artifact_path].uniq.each { |path| @ceedling[:file_wrapper].mkdir( path ) }

    log( "Building dependency #{spec.name}..." )
    commands.build( spec ).each do |step|
      next build_builtin( step, spec ) if step.is_a?( Symbol )

      in_directory( spec.source_path ) { @ceedling[:tool_executor].exec( step ) }
    end
  end

  def build_builtin(step, spec)
    return build_lib( spec ) if step == :build_lib

    raise CeedlingException.new( "No such build action as #{step.inspect} for dependency #{spec.name}" )
  end

  # Compiles every C and assembly file under the source path, archives the objects into
  # the dependency's first static library in the build path, and copies that library to
  # the artifact path when the two differ
  def build_lib(spec)
    library = spec.static_library_entries.first or
      raise CeedlingException.new( "Dependency `#{spec.name}` needs a :static_libraries entry for :build_lib to build." )

    sources, assembly, search_paths = build_lib_inputs( spec )
    check_tools( *(sources.empty? ? [] : [TOOLS_DEPS_COMPILER]), *(assembly.empty? ? [] : [TOOLS_DEPS_ASSEMBLER]), TOOLS_DEPS_LINKER )
    objects = sources.map { |source| compile( spec, source, search_paths ) } +
              assembly.map { |source| assemble( spec, source ) }

    built = File.join( spec.build_path, library )
    @ceedling[:file_wrapper].mkdir( File.dirname( built ) )
    @ceedling[:generator].generate_executable_file(
      TOOLS_DEPS_LINKER, DEPENDENCIES_SYM, objects, [], built,
      @ceedling[:file_path_utils].form_test_build_map_filepath( spec.artifact_path, library ),
      spec.libraries, spec.libpaths
    )

    copy_library( built, File.join( spec.artifact_path, library ) ) unless spec.build_path == spec.artifact_path
  end

  # Sources, assembly files, and the search paths to compile them with: every directory
  # holding a header under the source path, plus any the dependency names
  def build_lib_inputs(spec)
    sources  = listing( spec, EXTENSION_SOURCE )
    assembly = (defined?( EXTENSION_ASSEMBLY ) and EXTENSION_ASSEMBLY.any?) ? listing( spec, EXTENSION_ASSEMBLY ) : []
    headers  = listing( spec, EXTENSION_HEADER ).map { |header| File.dirname( header ) }.uniq

    raise CeedlingException.new( "Dependency `#{spec.name}` has nothing under #{spec.source_path} to build." ) if sources.empty? and assembly.empty?
    raise CeedlingException.new( "No assembler specified for building dependency `#{spec.name}`." ) unless assembly.empty? or defined?( TOOLS_DEPS_ASSEMBLER )

    search_paths = headers + spec.build_lib_search_paths

    # Custom compiler configurations may still read these, set once per dependency
    replace_constant( :COLLECTION_PATHS_DEPS, search_paths )
    replace_constant( :COLLECTION_DEFINES_DEPS, spec.defines )

    return sources, assembly, search_paths
  end

  # Every file of a type anywhere under the dependency's source path
  def listing(spec, extension)
    return extension.glob_patterns( File.join( spec.source_path, '**' ) ).flat_map do |glob|
      @ceedling[:file_wrapper].directory_listing( glob )
    end
  end

  def compile(spec, source, search_paths)
    object = object_for( spec, source )
    @ceedling[:generator].generate_object_file_c(
      tool:         TOOLS_DEPS_COMPILER,
      module_name:  File.basename( source ).ext,
      context:      DEPENDENCIES_SYM,
      source:       source,
      object:       object,
      search_paths: search_paths,
      flags:        spec.flags,
      defines:      spec.defines,
      list:         @ceedling[:file_path_utils].form_release_build_list_filepath( File.basename( source ).ext )
    )
    return object
  end

  def assemble(spec, source)
    object = object_for( spec, source )
    @ceedling[:generator].generate_object_file_asm(
      tool: TOOLS_DEPS_ASSEMBLER, module_name: File.basename( source ).ext, context: DEPENDENCIES_SYM,
      source: source, object: object
    )
    return object
  end

  def object_for(spec, source)
    return File.join( spec.build_path, File.basename( source ).ext( EXTENSION_OBJECT.primary ) )
  end

  def copy_library(built, destination)
    @ceedling[:file_wrapper].mkdir( File.dirname( destination ) )
    @ceedling[:file_wrapper].cp( built, destination )
  end

  def replace_constant(constant, new_value)
    Object.send( :remove_const, constant ) if Object.const_defined?( constant )
    Object.const_set( constant, new_value )
  end

  INCLUDE_COLLECTIONS = %i[collection_paths_include collection_paths_source_and_include collection_paths_test_support_source_include
                           collection_paths_test_support_source_include_vendor collection_paths_release_toolchain_include].freeze

  def add_include_directories(cfg, directories)
    directories.each { |directory| INCLUDE_COLLECTIONS.each { |key| cfg[key] << directory } }
  end

  # A source path joins the search collections, and its C files join the source collection
  def add_source_path(cfg, source)
    INCLUDE_COLLECTIONS.drop( 1 ).each { |key| cfg[key] << source }

    EXTENSION_SOURCE.glob_patterns( source ).each do |glob|
      cfg[:collection_all_source].concat( @ceedling[:file_wrapper].directory_listing( glob ) )
    end
  end

  # The tools a fetch method runs. Unknown methods are already refused by DependencySpec.
  def fetch_tools(method)
    return { zip: [TOOLS_DEPS_ZIP], tar_gzip: [TOOLS_DEPS_TARGZIP], git: [TOOLS_DEPS_GIT_CLONE, TOOLS_DEPS_GIT_CHECKOUT],
             svn: [TOOLS_DEPS_SUBVERSION] }.fetch( method, [] )
  end

  # Each tool is checked once, just before its first use, so a tool only some dependency
  # or task needs never becomes a requirement of every Ceedling command
  def check_tools(*tools)
    @checked_tools ||= []
    tools.each do |tool|
      next if @checked_tools.include?( tool )

      @ceedling[:tool_validator].validate( tool: tool, boom: true )
      @checked_tools << tool
    end
  end

end
