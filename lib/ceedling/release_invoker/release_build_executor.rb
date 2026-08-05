# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/release_invoker/release_invoker_types'

# Does the actual work of a release build: compiling objects, linking the
# artifact, and copying it into place -- the only class in this subsystem
# that invokes tools or talks to the dependency tracker.
class ReleaseBuildExecutor

  include ReleaseInvokerTypes

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :generator,
    :file_finder,
    :file_wrapper,
    :file_path_utils,
    :dependinator
  )

  def compile_objects(state)
    skipped = 0

    @batchinator.exec(workload: :compile, things: state.objects) do |object|
      compiled = compile_release_component( object: object, state: state )
      skipped += 1 unless compiled
    end

    log_skip_summary( task: "compilation", count: skipped, noun: "objects" )
  end

  def link(state)
    objects, libraries = sort_objects_and_libraries( state.objects )
    lib_args  = convert_libraries_to_arguments( libraries )
    lib_paths = get_library_paths_to_arguments()
    target    = @configurator.project_release_build_target

    @dependinator.register(
      target,
      files: objects,
      meta:  { flags: state.link_flags, lib_args: lib_args, lib_paths: lib_paths }
    )
    stale = @dependinator.stale?( target )

    if stale
      @generator.generate_executable_file(
        @configurator.tools_release_linker,
        RELEASE_SYM,
        objects,
        state.link_flags,
        target,
        @configurator.project_release_build_map,
        lib_args,
        lib_paths
      )

      @dependinator.mark_fresh( target )
    else
      msg = @reportinator.generate_progress( "Skipping linking for #{File.basename( target )}" )
      @loginator.log( msg, Verbosity::OBNOXIOUS )
    end

    log_skip_summary( task: "linking", count: (stale ? 0 : 1), noun: "executables" )

    # #artifactinate relies on this rather than a second `stale?` call -- by
    # now `mark_fresh` above (when `stale` was true) has already updated the
    # cache entry to match the executable's current state, so a fresh
    # `stale?` query would always answer false.
    state.executable_rebuilt = stale
  end

  def artifactinate(state)
    artifacts = [
      @configurator.project_release_build_target,
      @configurator.project_release_build_map,
      @configurator.release_build_artifacts
    ].flatten

    unless state.executable_rebuilt
      log_skip_summary( task: "artifact collection", count: artifacts.size, noun: "artifacts" )
      return
    end

    artifacts.each do |file|
      @file_wrapper.cp( file, @configurator.project_release_artifacts_path ) if @file_wrapper.exist?( file )
    end
  end

  private

  # Compile a single C or assembly source file into an object file. Returns
  # whether a real compile actually happened, so the caller can report how
  # many objects across the whole build needed nothing done.
  def compile_release_component(object:, state:)
    source       = @file_finder.find_build_input_file( filepath: object, context: RELEASE_SYM )
    dependencies = @file_path_utils.form_release_dependencies_filepath( object )

    if @file_wrapper.extname( source ) != @configurator.extension_assembly
      flags = state.compile_flags
      stale = register_and_check_object_staleness( object: object, source: source, dependencies: dependencies, flags: flags, defines: state.defines, search_paths: state.search_paths )

      return log_compile_skip( source: source ) unless stale

      @generator.generate_object_file_c(
        tool:         @configurator.tools_release_compiler,
        module_name:  File.basename( source ).ext(),
        context:      RELEASE_SYM,
        source:       source,
        object:       object,
        search_paths: state.search_paths,
        flags:        flags,
        defines:      state.defines,
        list:         @file_path_utils.form_release_build_list_filepath( object ),
        dependencies: dependencies
      )
    else
      flags = state.assemble_flags
      stale = register_and_check_object_staleness( object: object, source: source, dependencies: dependencies, flags: flags, defines: state.defines, search_paths: state.search_paths )

      return log_compile_skip( source: source ) unless stale

      @generator.generate_object_file_asm(
        tool:         @configurator.tools_release_assembler,
        module_name:  File.basename( source ).ext(),
        context:      RELEASE_SYM,
        source:       source,
        object:       object,
        search_paths: state.search_paths,
        flags:        flags,
        defines:      state.defines,
        list:         @file_path_utils.form_release_build_list_filepath( object ),
        dependencies: dependencies
      )
    end

    # A real (re)compile just happened -- register_gcc_deps_file again to pick
    # up the freshly-written `.d` file's current header set (only produced for
    # C compiles; a no-op call for assembly, whose tool has no -MMD/-MF) before
    # recording this target's new baseline.
    @dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
    @dependinator.mark_fresh( object )

    true
  end

  # Reports that a single object file needed no recompiling, at a verbosity
  # meant for readers who want every target accounted for individually
  # rather than just the batch total.
  def log_compile_skip(source:)
    msg = @reportinator.generate_progress( "Skipping compilation for #{File.basename( source )}" )
    @loginator.log( msg, Verbosity::OBNOXIOUS )
    false
  end

  # Registers `object`'s antecedents (its source file, plus whatever headers
  # gcc's `-MMD -MF` discovered on the *previous* successful compile, if any)
  # and reports whether it needs (re)building. The previous run's `.d` file is
  # the only header list available before this run's compile has happened --
  # if headers changed, that's exactly what makes this stale.
  def register_and_check_object_staleness(object:, source:, dependencies:, flags:, defines:, search_paths:)
    @dependinator.register( object, files: [source], meta: { flags: flags, defines: defines, search_paths: search_paths } )
    @dependinator.register_gcc_deps_file( dependencies ) if @file_wrapper.exist?( dependencies )
    @dependinator.stale?( object )
  end

  def convert_libraries_to_arguments(libraries)
    args =
      (libraries || []) +
      ((defined? LIBRARIES_SYSTEM) ? LIBRARIES_SYSTEM : []) +
      ((defined? LIBRARIES_RELEASE) ? LIBRARIES_RELEASE : [])

    args.flatten!
    args.compact!

    if (defined? LIBRARIES_FLAG)
      args.map! { |v| LIBRARIES_FLAG.gsub(/\$\{1\}/, v) }
    end

    return args
  end

  def get_library_paths_to_arguments()
    paths = (defined? PATHS_LIBRARIES) ? (PATHS_LIBRARIES || []).clone : []
    if (defined? LIBRARIES_PATH_FLAG)
      paths.map! { |v| LIBRARIES_PATH_FLAG.gsub(/\$\{1\}/, v) }
    end
    return paths
  end

  # A release's object list can include precompiled libraries/archives
  # alongside plain compiled objects (via :libraries ↳ :release or extra
  # link-only entries) -- these need to reach the linker as -l-style
  # arguments rather than as ordinary link inputs, so they're split out here
  # by file extension before linking.
  def sort_objects_and_libraries(both)
    extension = if ((defined? EXTENSION_SUBPROJECTS) && (defined? EXTENSION_LIBRARIES))
      extension_libraries = if (EXTENSION_LIBRARIES.class == Array)
                              EXTENSION_LIBRARIES.join(")|(?:\\")
                            else
                              EXTENSION_LIBRARIES
                            end
      "(?:\\#{EXTENSION_SUBPROJECTS})|(?:\\#{extension_libraries})"
    elsif (defined? EXTENSION_SUBPROJECTS)
      "\\#{EXTENSION_SUBPROJECTS}"
    elsif (defined? EXTENSION_LIBRARIES)
      if (EXTENSION_LIBRARIES.class == Array)
        "(?:\\#{EXTENSION_LIBRARIES.join(")|(?:\\")})"
      else
        "\\#{EXTENSION_LIBRARIES}"
      end
    else
      "\\.LIBRARY"
    end
    sorted_objects = both.group_by { |v| v.match(/.+#{extension}$/) ? :libraries : :objects }
    libraries = sorted_objects[:libraries] || []
    objects   = sorted_objects[:objects]   || []
    return objects, libraries
  end

  # States, in one line, how many targets a build step left untouched because nothing
  # about them needed attention this run. Silent when nothing was skipped, so a full
  # rebuild's output isn't cluttered with zero counts.
  def log_skip_summary(task:, count:, noun:, reason: "nothing changed")
    return if count == 0
    singular_noun = noun.sub(/s$/, '')
    @loginator.log( "Skipping #{task} for #{count} #{count == 1 ? singular_noun : noun} -- #{reason}" )
  end

end
