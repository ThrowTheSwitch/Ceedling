# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for ext()
require 'fileutils'
require 'pathname'
require 'ceedling/exceptions'
require 'set'
require 'ceedling/system_wrapper'
require 'ceedling/constants'
require 'ceedling/filesystem/path_mirror'
require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/project_paths'
require 'ceedling/filesystem/build_subpath'
require 'ceedling/filesystem/destination_collision'

# global utility methods (for plugins, project files, etc.)
def ceedling_form_filepath(destination_path, original_filepath, new_extension=nil)
  filename = File.basename(original_filepath)
  filename.replace(filename.ext(new_extension)) if (!new_extension.nil?)
  return File.join( destination_path.tr("\\", '/'), filename )
end

class FilePathUtils

  constructor :configurator, :file_wrapper

  def setup
    @formed_lock  = Mutex.new
    @formed_paths = Set.new
  end

  ######### Class methods ##########

  # Standardize path to use '/' separator & have no trailing separator. Mutates in place.
  # Frozen strings are a programming error at the call site — raises CeedlingException.
  def self.standardize_in_place(path)
    if path.is_a? String
      raise CeedlingException.new("Attempted to standardize path in frozen string ⏩️ #{path.inspect}") if path.frozen?
      path.replace( ProjectPaths.standardize( path ) )
    end
    return path
  end

  def self.os_executable_ext(executable)
    return executable.ext( EXTENSION_WIN_EXE ) if SystemWrapper.windows?
    return executable
  end

  # Extract path from between optional aggregation modifiers
  # and up to last path separator before glob specifiers.
  # Examples:
  #  - '+:foo/bar/baz/'       => 'foo/bar/baz'
  #  - 'foo/bar/ba?'          => 'foo/bar'
  #  - 'foo/bar/baz/'         => 'foo/bar/baz'
  #  - 'foo/bar/baz/file.x'   => 'foo/bar/baz/file.x'
  #  - 'foo/bar/baz/file*.x'  => 'foo/bar/baz'
  # NOTE: Input is assumed to use forward slashes; backslash paths must be normalized by caller.
  def self.no_decorators(path)
    return '' if path.nil?

    path = self.no_aggregation_decorators(path)

    # Find first occurrence of glob specifier: *, ?, {, }, [, ]
    find_index = (path =~ PATTERNS::GLOB)

    # Return empty path if first character is part of a glob
    return '' if find_index == 0

    # If path contains no glob, clean it up and return whole path
    return path.chomp('/') if find_index.nil?

    # Extract up to first glob specifier
    path = path[0..(find_index-1)]

    # Keep everything up to and including the final path separator before the glob.
    # Three cases for the separator position:
    #   nil  — no separator at all (e.g. 'src*.c'): no usable directory prefix
    #   0    — separator is at position 0 (e.g. '/*.c'): root directory
    #   else — separator somewhere in the middle: slice off the trailing segment
    find_index = path.rindex('/')
    return '' if find_index.nil?
    return '/' if find_index == 0
    return path[0..(find_index-1)]
  end

  # #104 -- `[`/`]` are legal filename characters (Windows especially) but Ruby's
  # `Dir.glob`/`File.fnmatch` treat an unescaped `[...]` as character-class glob
  # syntax, so a literal bracket in a real directory name silently fails to match
  # its own glob pattern. Ceedling has no glob-escape helper of its own and Ruby
  # provides none for this (unlike `Regexp.escape` for regexes), so this backslash-
  # escapes just those two characters. Callers apply this only to the raw,
  # user-supplied path *segment* of a pattern they're about to build -- never to a
  # glob suffix Ceedling itself appends (e.g. `'*.rb'`/`'**/*.c'`), which must stay
  # glob-active.
  def self.escape_glob_brackets(path)
    return path if path.nil?
    return path.gsub(/([\[\]])/) { "\\#{$1}" }
  end

  # #104 -- the single, canonical way to turn a (possibly bracket-containing) base
  # directory path into a glob pattern safe for anything that (re-)interprets it as
  # a glob (`FileWrapper#directory_listing`, `Rake::FileList#include`,
  # `FileWrapper#instantiate_file_list`). `escape_glob_brackets` alone only protects
  # a call site that remembers to invoke it -- several didn't, because building the
  # pattern via a bare `File.join(path, suffix)` gives no signal escaping was ever
  # needed. Routing every base-path-plus-suffix glob pattern through this instead
  # makes that omission structurally harder to repeat.
  def self.glob(base_path, *suffix)
    return File.join( escape_glob_brackets( base_path ), *suffix )
  end

  # Same escaping guarantee as `glob`, for the one caller shape that reforms
  # Ceedling's own trailing `/**` recursive-directory convention instead of
  # appending a suffix. `reform_subdirectory_glob` only inspects/appends based on
  # a trailing `**`, so escaping first doesn't interfere with its own logic.
  def self.subdirectory_glob(path)
    return reform_subdirectory_glob( escape_glob_brackets( path ) )
  end

  # Return whether the given path is to be aggregated (no aggregation modifier defaults to same as +:).
  # nil is treated as an additive (non-excluding) path.
  def self.add_path?(path)
    return true if path.nil?
    return !path.strip.start_with?('-:')
  end

  # Get path (and glob) stripping optional +: / -: prefixed aggregation modifiers.
  # Strip surrounding whitespace before the regex so a decorator preceded by whitespace
  # (e.g. '  -:foo') is handled consistently with add_path?, which also strips first.
  def self.no_aggregation_decorators(path)
    return '' if path.nil?
    return path.strip.sub(/^(\+|-):/, '').strip()
  end

  # To recurse through all subdirectories, the Ruby glob is <dir>/**/**, but our paths use
  # convenience convention of only <dir>/** at tail end of a path.
  # Paths with ** at non-tail positions (e.g. foo/**/bar) are left unchanged by design.
  def self.reform_subdirectory_glob(path)
    return '' if path.nil?
    return path if path.end_with?( '/**/**' )
    return path + '/**' if path.end_with?( '/**' )
    return path
  end

  # Reduce a list of directory paths to the minimal ancestor set by removing any path
  # that is already a descendant of another path in the list. This shortens command
  # lines when a path list contains both a parent and a child directory.
  #
  # Examples:
  #   ['src', 'src/platform', 'lib']   =>  ['src', 'lib']
  #   ['a/b', 'a/c', 'a']             =>  ['a']
  #   ['src', 'lib/core', 'lib/utils'] =>  ['src', 'lib/core', 'lib/utils']  (unchanged)
  #
  # Paths compare as the directories they name (ProjectPaths.contains?), so `..` holds
  # `../sib` but not `../../far/x`. Returned paths preserve the form the caller supplied.
  def self.collapse_to_common_parents(paths)
    return paths if paths.nil? || paths.length <= 1

    # Shortest absolute spelling first, so an ancestor is always met before what it holds
    pairs = paths.map { |path| [path, ProjectPaths.absolute( path )] }.sort_by { |_, absolute| absolute.length }

    return outermost( pairs ).map { |original, _| original }
  end

  # The [original, absolute] pairs no earlier pair's directory holds
  def self.outermost(pairs)
    return pairs.each_with_object( [] ) do |pair, kept|
      kept << pair unless kept.any? { |_, held| ProjectPaths.contains?( held, pair.last ) }
    end
  end
  private_class_method :outermost


  ######### Instance methods ##########

  ### Release ###

  # `filepath` is an already-mirrored object path -- recovering the mirrored subdirectory
  # beyond the release build output root and re-rooting it under the dependencies path
  # keeps this dependencies file alongside the same-named object it accompanies, rather
  # than colliding with another object's dependencies file at a shared flat basename.
  def form_release_dependencies_filepath(filepath)
    subdir   = PathMirror.relative_subdir( filepath, [@configurator.project_release_build_output_path] )
    basename = File.basename(filepath).ext(@configurator.extension_dependencies.primary)
    root     = @configurator.project_release_dependencies_path
    return subdir.empty? ? File.join(root, basename) : File.join(root, subdir, basename)
  end

  def form_release_build_objects_filelist(files)
    return mirror_build_objects( files, root: @configurator.project_release_build_output_path, ext: @configurator.extension_object.primary )
  end

  # `filepath` is an already-mirrored object path -- its own directory is exactly where its
  # list file belongs too, so no separate mirroring of its own is needed here.
  def form_release_build_list_filepath(filepath)
    return File.join( File.dirname(filepath), File.basename(filepath).ext(@configurator.extension_list.primary) )
  end

  def form_release_dependencies_filelist(files)
    return mirror_build_objects( files, root: @configurator.project_release_dependencies_path, ext: @configurator.extension_dependencies.primary )
  end

  ### Tests ###

  # A test is named by its path from the project root, without its extension. The name places
  # the test's build, results, runner, mock, preprocessing and log directories, and a path is
  # unique, so no two tests share them. A test outside the project keeps its whole path too,
  # with each `..` written as `_up_`, and a path with no relative form (another Windows drive)
  # placed under `_abs_`, so no name reaches outside the build directory.
  def form_test_name(filepath)
    return BuildSubpath.encode( filepath.to_s.ext( '' ) )
  end

  def form_test_build_path(name, context: nil)
    form_build_context_path(BUILD_OUT_DIR, name: name, context: context)
  end

  # Where a build places the object of `filepath`: below its test's build path, or below the
  # context's own output root for a source compiled outside any test
  def form_test_object_filepath(filepath, name: nil, context: nil)
    root = form_build_context_path( BUILD_OUT_DIR, name: name, context: context )
    return build_filepath( filepath, root: root, ext: @configurator.extension_object.primary, generated_roots: generated_roots( name ) )
  end

  # As `form_test_runners_path`: a test's results sit beneath the directories of its name,
  # so same-named tests in different directories keep apart. Only a test at the project
  # root uses the results directory itself.
  def form_test_results_path(name = nil, context: nil)
    subdir = name.nil? ? '' : mirrored_test_subdir(name)
    return form_build_context_path(BUILD_RESULTS_DIR, context: context) if subdir.empty?
    return form_build_context_path(BUILD_RESULTS_DIR, name: subdir, context: context)
  end

  # Forms the filepath for the gdb backtrace log for a given test case.
  # Produces: <project_log_path>/<context>/<test>/<name>.gdb.log
  def form_test_gdb_log(test, context:, name:)
    parts = [@configurator.project_log_path]
    parts << context.to_s
    parts << test
    parts << "#{name}.gdb.log"
    File.join( *parts )
  end

  def form_test_dependencies_path(name, context: nil)
    form_build_context_path(BUILD_DEPENDENCIES_DIR, name: name, context: context)
  end

  # `filepath` is an object path. Its dependencies file sits at the object's own place below
  # the dependencies root, so it never collides with another same-named object's. Without a
  # test, that place is below the context's own output root.
  def form_test_dependencies_filepath(filepath, name: nil, context: nil)
    root     = form_build_context_path(BUILD_DEPENDENCIES_DIR, name: name, context: context)
    basename = File.basename(filepath).ext(@configurator.extension_dependencies.primary)

    subdir = ProjectPaths.subdir_below( form_test_build_path( name, context: context ), File.dirname( filepath ) ) || ''
    return subdir.empty? ? File.join(root, basename) : File.join(root, subdir, basename)
  end

  def form_test_mocks_path(name)
    form_named_path(@configurator.cmock_mock_path, name)
  end

  def form_test_partials_path(name)
    form_named_path(@configurator.project_test_partials_path, name)
  end

  def form_test_preprocess_includes_path(name)
    form_named_path(@configurator.project_test_preprocess_includes_path, name)
  end

  def form_test_preprocess_files_path(name)
    form_named_path(@configurator.project_test_preprocess_files_path, name)
  end

  def form_test_preprocess_files_full_expansion_path(name)
    form_named_path(@configurator.project_test_preprocess_files_path, name, subdir: PREPROCESS_FULL_EXPANSION_DIR)
  end

  def form_test_preprocess_files_directives_only_path(name)
    form_named_path(@configurator.project_test_preprocess_files_path, name, subdir: PREPROCESS_DIRECTIVES_ONLY_DIR)
  end

  def form_test_preprocess_files_raw_directives_only_path(name)
    form_named_path(@configurator.project_test_preprocess_files_path, name, subdir: PREPROCESS_RAW_DIRECTIVES_ONLY_DIR)
  end

  def form_test_preprocess_build_directives_path(name)
    form_named_path(@configurator.project_test_preprocess_build_directives_path, name)
  end

  # Where a test file's own #include/build-directive scan results are cached, keyed by
  # the test file's own name so each test's cache lives alongside its other
  # preprocessing artifacts.
  def form_test_build_directives_cache_filepath(filepath, subdir)
    return File.join( @configurator.project_test_preprocess_build_directives_path, subdir, File.basename(filepath) + EXTENSION_CORE_YAML )
  end

  # Where a test file's TEST_SOURCE_FILE() results are cached once its preprocessed
  # output has been generated -- kept distinct from the raw-file cache above since the
  # two are populated at different points in the pipeline from different content.
  def form_preprocessed_source_files_cache_filepath(filepath, subdir)
    return File.join( @configurator.project_test_preprocess_build_directives_path, subdir, File.basename(filepath) + '_source_files' + EXTENSION_CORE_YAML )
  end

  def form_pass_results_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_testpass.primary) )
  end

  def form_fail_results_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_testfail.primary) )
  end

  # A test's runner sits beneath the directories of its name, so same-named tests in
  # different directories keep apart. Only a test at the project root uses the runners
  # directory itself.
  def form_test_runners_path(name)
    subdir = mirrored_test_subdir(name)
    return @configurator.project_test_runners_path if subdir.empty?
    return File.join(@configurator.project_test_runners_path, subdir)
  end

  def form_runner_filepath_from_test(filepath, name: nil)
    # Strip whatever extension the test file actually carries -- there's no need to consult
    # the configured source extension(s) here, since the basename's own suffix is already
    # known to be a valid one by the time a runner is being formed for it.
    basename = File.basename(filepath, File.extname(filepath))
    root = name ? form_test_runners_path(name) : @configurator.project_test_runners_path
    return File.join( root, basename) + @configurator.test_runner_file_suffix + EXTENSION_CORE_SOURCE
  end

  def form_test_filepath_from_runner(filepath)
    return filepath.sub(/#{Regexp.escape(TEST_RUNNER_FILE_SUFFIX)}/, '')
  end

  def form_test_executable_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_executable.primary) )
  end

  def form_test_build_map_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_map.primary) )
  end

  # `filepath` is an already-mirrored object path -- its own directory is exactly where its
  # list file belongs too, so no separate mirroring of its own is needed here.
  def form_test_build_list_filepath(filepath)
    return File.join( File.dirname(filepath), File.basename(filepath).ext(@configurator.extension_list.primary) )
  end

  # A preprocessed artifact's name below its test's own subdirectory. The test subdirectory
  # alone kept artifacts apart while a test had at most one source of any given basename.
  # Two same-basename sources in one test overwrite each other, so the file's own namespace
  # below its configured root is carried forward too.
  #
  # A file below none of those roots mirrors nothing and keeps the flat name it has always
  # had. Ceedling's own generated files are the exception: `test` names which test's
  # generated roots to measure against as well, since a mock or a Partial sits below one
  # of those rather than anything the project configured. Every caller derives this from
  # the same filepath, so all of them agree on where the artifact lands without
  # coordinating.
  def preprocessed_file_subpath(filepath, test = nil)
    subdir   = form_build_subpath( filepath, generated_roots: generated_roots( test ) )
    basename = File.basename( filepath )

    return basename if subdir.empty?

    return File.join( subdir, basename )
  end

  # The roots holding one test's own generated files. A mock or a generated Partial sits
  # below one of these rather than a configured source root, and two same-named modules
  # each produce one, so without these roots both share a single preprocessed artifact.
  #
  # Each root carries the test's own name, so what mirrors forward is the module's own
  # subdirectory rather than the test name a second time.
  def generated_roots(test)
    return [] if test.nil?

    roots = []
    roots << File.join( @configurator.project_test_partials_path, test ) if @configurator.project_use_partials
    roots << File.join( @configurator.cmock_mock_path, test ) if @configurator.project_use_mocks

    return roots
  end

  # Composes a preprocessed artifact's path. Pure, like every other path builder here:
  # callers that merely restate a path -- a rake target declaration, a staleness check --
  # must not leave directories behind as a side effect. Whoever writes the file creates
  # its directory, the same way a mock's or a Partial's own writer does.
  def form_preprocessed_filepath(root, subdir, kind_dir, filepath, suffix: '')
    return File.join( *[root, subdir, kind_dir, preprocessed_file_subpath( filepath, subdir ) + suffix].compact )
  end

  def form_preprocessed_includes_list_filepath(filepath, subdir)
    return form_preprocessed_filepath(
      @configurator.project_test_preprocess_includes_path, subdir, nil, filepath, suffix: EXTENSION_CORE_YAML
    )
  end

  def form_preprocessed_file_filepath(filepath, subdir)
    return form_preprocessed_filepath( @configurator.project_test_preprocess_files_path, subdir, nil, filepath )
  end

  def form_preprocessed_file_full_expansion_filepath(filepath, subdir)
    return form_preprocessed_filepath(
      @configurator.project_test_preprocess_files_path, subdir, PREPROCESS_FULL_EXPANSION_DIR, filepath
    )
  end

  def form_preprocessed_file_raw_directives_only_filepath(filepath, subdir)
    return form_preprocessed_filepath(
      @configurator.project_test_preprocess_files_path, subdir, PREPROCESS_RAW_DIRECTIVES_ONLY_DIR, filepath
    )
  end

  def form_preprocessed_file_fallback_expansion_filepath(filepath, subdir)
    return form_preprocessed_filepath(
      @configurator.project_test_preprocess_files_path, subdir, PREPROCESS_FALLBACK_EXPANSION_DIR, filepath
    )
  end

  def form_preprocessed_file_compacted_directives_only_filepath(filepath, subdir)
    return form_preprocessed_filepath(
      @configurator.project_test_preprocess_files_path, subdir, PREPROCESS_DIRECTIVES_ONLY_DIR, filepath
    )
  end

  # `extra_roots` carries roots known only to the caller. A generated Partial source sits
  # below its own test's build root rather than a configured source root, so nothing in the
  # standard roots mirrors it. Without its root here, two modules sharing a basename
  # collapse onto one object filename.
  def form_test_build_objects_filelist(path, sources, extra_roots: [])
    return mirror_build_objects( sources, root: path, ext: @configurator.extension_object.primary, generated_roots: extra_roots )
  end

  # Where one mock's generated files sit: its test's mock root, plus the subdirectory
  # mirroring whatever it mocks. Shared by the stage that compiles a mock and the stage
  # that generates it, so the two cannot disagree about where a mock lives.
  def form_mock_output_path(root, subdir)
    return root if subdir.nil? || subdir.empty?

    return File.join( root, subdir )
  end

  def form_mock_header_filepath(subdir, filename)
    # @configurator.cmock_mock_path accessor only exists if mocks are enabled
    raise CeedlingException.new('Mocks are not enabled, but an internal feature dependent on them was accessed.') unless @configurator.project_use_mocks
    return File.join(@configurator.cmock_mock_path, subdir, filename.ext(EXTENSION_CORE_HEADER))
  end

  def form_partial_header_filepath(subdir, filename)
    # @configurator.project_test_partials_path accessor only exists if partials are enabled
    raise CeedlingException.new('Partials are not enabled, but an internal feature dependent on them was accessed.') unless @configurator.project_use_partials
    return File.join( @configurator.project_test_partials_path, subdir, filename.ext(EXTENSION_CORE_HEADER) )
  end

  # Every generated Partial filename below is also the text a Partial directive macro
  # expands to, so the two have to agree exactly or the compiler resolves the generated
  # #include to nothing.
  #
  # A module named by directory keeps that directory and takes its prefixes on the
  # basename, matching how the macro assembles the same name. Concatenating the whole
  # module name instead would put the prefix on the first path segment.
  def form_partial_filename(_module, suffix, extension, prefix: '')
    dir      = File.dirname( _module )
    basename = prefix + PARTIAL_FILENAME_PREFIX + File.basename( _module ) + suffix + extension

    return basename if dir == '.'

    return File.join( dir, basename )
  end

  # Reverses form_partial_filename(). A generated Partial filename is Ceedling's own
  # invention, so a message naming one tells a test author nothing. Recovering the module
  # lets a message name what the author actually wrote.
  #
  # Prefixes stack on a mocked interface header, mock outermost. The suffix is stripped
  # from the end only, so a module whose own name ends in a suffix word survives. Returns
  # nil for any filename this builder could not have produced.
  def module_from_partial_filename(filepath)
    dir      = File.dirname( filepath )
    basename = File.basename( filepath ).ext('')

    basename = basename.delete_prefix( @configurator.cmock_mock_prefix )

    return nil unless basename.start_with?( PARTIAL_FILENAME_PREFIX )

    basename = basename.delete_prefix( PARTIAL_FILENAME_PREFIX )

    suffix = PARTIAL_FILENAME_SUFFIXES.find { |candidate| basename.end_with?( candidate ) }

    return nil if suffix.nil?

    basename = basename.delete_suffix( suffix )

    return basename if dir == '.'

    return File.join( dir, basename )
  end

  def form_partial_interface_header_filename(_module)
    return form_partial_filename( _module, PARTIAL_SUFFIX_INTERFACE, EXTENSION_CORE_HEADER )
  end

  # A module's typedefs and aggregate (struct/enum/union) definitions are generated into this
  # standalone header, shared by both the implementation and interface headers below, so a
  # module tested and mocked in the same file never has its types defined more than once.
  def form_partial_types_header_filename(_module)
    return form_partial_filename( _module, PARTIAL_SUFFIX_TYPES, EXTENSION_CORE_HEADER )
  end

  def form_mock_partial_interface_header_filename(_module)
    return form_partial_filename( _module, PARTIAL_SUFFIX_INTERFACE, EXTENSION_CORE_HEADER, prefix: @configurator.cmock_mock_prefix )
  end

  def form_partial_implementation_header_filename(_module)
    return form_partial_filename( _module, PARTIAL_SUFFIX_IMPL, EXTENSION_CORE_HEADER )
  end

  def form_partial_implementation_source_filename(_module)
    return form_partial_filename( _module, PARTIAL_SUFFIX_IMPL, EXTENSION_CORE_SOURCE )
  end

  # Each test's results file sits where `form_test_results_path` puts it, beneath its name
  def form_pass_results_filelist(path, files)
    results = @file_wrapper.instantiate_file_list_literal( files ).map do |file|
      subdir = mirrored_test_subdir( form_test_name( file ) )
      form_pass_results_filepath( subdir.empty? ? path : File.join( path, subdir ), file )
    end
    return @file_wrapper.instantiate_file_list_literal( results )
  end

  ### Private ###

  private

  # Forms project_build_root/[context/]subdir[/name]; context and name are omitted when nil
  def form_build_context_path(subdir, name: nil, context: nil)
    parts = [@configurator.project_build_root]
    parts << context.to_s if context
    parts << subdir
    parts << name if name
    path = File.join( *parts )
    @file_wrapper.check_path_length( path, origin: 'FilePathUtils#form_build_context_path' )
    return path
  end

  # Forms base/name[/subdir]
  def form_named_path(base, name, subdir: nil)
    path = subdir ? File.join( base, name, subdir ) : File.join( base, name )
    @file_wrapper.check_path_length( path, origin: 'FilePathUtils#form_named_path' )
    return path
  end

  # The directories of a test's name, excluding its basename: 'test/unit' for
  # 'test/unit/test_foo', or '' for a test at the project root.
  def mirrored_test_subdir(name)
    dir = File.dirname(name)
    return '' if dir == '.'
    return dir
  end

  # Maps each file to root/[mirrored subdir/]basename.ext, mirroring whichever configured
  # root in `roots` the file lives under -- e.g. a source file in a second configured
  # source directory lands in its own mirrored subdirectory rather than colliding with a
  # same-named object from the first. A file matching none of `roots` (a mock's own bare
  # basename, a vendor framework file, the test file itself under its own build path) is
  # left flat under `root`.
  # #104 -- `files` (and, below, the `objects` this method itself computes) are already
  # fully concrete filepaths -- nothing to glob-expand, no search to perform -- but
  # `objects`' own entries in particular don't exist on disk yet at all (they're this
  # very build's *about-to-be-compiled* output). FileWrapper#instantiate_file_list
  # (Rake::FileList.new/#include) treats every entry as a glob pattern to resolve via
  # Dir.glob regardless, which can only ever match files that already exist -- so a
  # not-yet-existing object path is silently dropped outright, independent of whether
  # it contains a literal `[`/`]`. FileWrapper#instantiate_file_list_literal (`<<`, not
  # `.new`/`.include`) adds every entry as-is, with no glob interpretation at all -- the
  # correct construction for a list that's already the real, final answer.
  def mirror_build_objects(files, root:, ext:, generated_roots: [])
    sources = @file_wrapper.instantiate_file_list_literal( files ).to_a.uniq { |file| ProjectPaths.absolute( file ) }
    objects = sources.map { |file| build_filepath( file, root: root, ext: ext, generated_roots: generated_roots ) }

    validate_distinct_build_files!( sources, objects )
    return @file_wrapper.instantiate_file_list_literal( objects )
  end

  def build_filepath(file, root:, ext:, generated_roots:)
    subdir   = form_build_subpath( file, generated_roots: generated_roots )
    basename = File.basename( file ).ext( ext )
    path     = subdir.empty? ? File.join( root, basename ) : File.join( root, subdir, basename )

    # A source far from the project gains a directory for each level its path climbs. Each
    # path is checked once, however often it is formed.
    @file_wrapper.check_path_length( path, origin: 'FilePathUtils#build_filepath' ) if first_formed?( path )
    return path
  end

  def first_formed?(path)
    return @formed_lock.synchronize { @formed_paths.add?( path ) }
  end

  # Where below a build output root the build file of `file` lands. A file below one of the
  # caller's generated roots (a test's mocks or Partials) mirrors below that root; one
  # below the build root otherwise (vendored frameworks, runners) lands flat; and any other
  # lands by its own path from the project root, so two sources never share one.
  def form_build_subpath(file, generated_roots: [])
    generated = PathMirror.relative_subdir_if_rooted_in_clean_roots( file, generated_roots )
    return generated unless generated.nil?
    return '' if ProjectPaths.contains?( @configurator.project_build_root, file )

    return BuildSubpath.of_directory( File.dirname( file ) )
  end

  # Two sources building to one file would leave one of them out of the build
  def validate_distinct_build_files!(sources, built)
    built_from = sources.zip( built ).to_h
    DestinationCollision.find( sources ) { |source| built_from[source] }.each do |file, sharing|
      DestinationCollision.raise_for( file, sharing, 'would build to the same file' )
    end
  end

end
