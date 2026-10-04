# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for ext()
require 'fileutils'
require 'ceedling/exceptions'
require 'ceedling/system_wrapper'
require 'ceedling/constants'
require 'ceedling/path_mirror'

# global utility methods (for plugins, project files, etc.)
def ceedling_form_filepath(destination_path, original_filepath, new_extension=nil)
  filename = File.basename(original_filepath)
  filename.replace(filename.ext(new_extension)) if (!new_extension.nil?)
  return File.join( destination_path.tr("\\", '/'), filename )
end

class FilePathUtils

  constructor :configurator, :file_wrapper


  ######### Class methods ##########

  # Standardize path to use '/' separator & have no trailing separator. Mutates in place.
  # Frozen strings are a programming error at the call site — raises CeedlingException.
  def self.standardize_in_place(path)
    if path.is_a? String
      raise CeedlingException.new("Attempted to standardize path in frozen string ⏩️ #{path.inspect}") if path.frozen?
      path.strip!
      path.tr!("\\", '/')
      path.chomp!('/')
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
  # Comparison uses forward-slash-normalized copies; returned paths preserve the original
  # form supplied by the caller.
  def self.collapse_to_common_parents(paths)
    return paths if paths.nil? || paths.length <= 1

    # Pair each original path with a normalized form used only for ancestry comparison.
    # Normalize to forward slashes and strip any trailing separator.
    pairs = paths.map { |p| [p, p.tr('\\', '/').chomp('/')] }

    # Sort shallowest-first so ancestors are always encountered before their descendants.
    # No tiebreaker for same-depth entries needed: Ruby's sort_by doesn't guarantee a
    # stable order among ties, but two same-depth paths can never be each other's
    # ancestor, so the ancestor-exclusion check below is correct regardless of which
    # order same-depth ties come out in.
    pairs.sort_by! { |_, normalized| normalized.count('/') }

    kept = []
    pairs.each do |original, normalized|
      # Skip this path if any already-kept path is a proper ancestor of it.
      next if kept.any? { |_, k| normalized.start_with?(k + '/') }
      kept << [original, normalized]
    end

    kept.map { |original, _| original }
  end


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
    return mirror_build_objects(
      files,
      root:  @configurator.project_release_build_output_path,
      ext:   @configurator.extension_object.primary,
      roots: @configurator.paths_source
    )
  end

  # `filepath` is an already-mirrored object path -- its own directory is exactly where its
  # list file belongs too, so no separate mirroring of its own is needed here.
  def form_release_build_list_filepath(filepath)
    return File.join( File.dirname(filepath), File.basename(filepath).ext(@configurator.extension_list.primary) )
  end

  def form_release_dependencies_filelist(files)
    return mirror_build_objects(
      files,
      root:  @configurator.project_release_dependencies_path,
      ext:   @configurator.extension_dependencies.primary,
      roots: @configurator.paths_source
    )
  end

  ### Tests ###

  def form_test_build_path(name, context: nil)
    form_build_context_path(BUILD_OUT_DIR, name: name, context: context)
  end

  def form_test_object_filepath(filepath, name: nil, context: nil)
    File.join(
      form_build_context_path(BUILD_OUT_DIR, name: name, context: context),
      File.basename(filepath).ext(@configurator.extension_object.primary)
    )
  end

  # As `form_test_runners_path`: a flat test's own identity forms the shared flat results
  # directory, untouched -- only a genuinely nested test's own mirrored subdirectory
  # becomes an extra directory level here, so two same-named tests land in distinct
  # results directories without perturbing the overwhelmingly common flat, non-duplicate
  # case.
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

  # `filepath` is an already-mirrored object path -- recovering the mirrored subdirectory
  # beyond the test's own build root and re-rooting it under this test's dependencies path
  # keeps this dependencies file alongside the same-named object it accompanies, rather
  # than colliding with another object's dependencies file at a shared flat basename.
  # Without a test identity to recover that build root from, there's no mirroring to do --
  # the dependencies file stays exactly where its context-level directory alone places it.
  def form_test_dependencies_filepath(filepath, name: nil, context: nil)
    root     = form_build_context_path(BUILD_DEPENDENCIES_DIR, name: name, context: context)
    basename = File.basename(filepath).ext(@configurator.extension_dependencies.primary)

    return File.join(root, basename) if name.nil?

    subdir = PathMirror.relative_subdir( filepath, [form_test_build_path(name, context: context)] )
    return subdir.empty? ? File.join(root, basename) : File.join(root, subdir, basename)
  end

  def form_test_mocks_path(name, context: nil)
    form_named_path(@configurator.cmock_mock_path, name)
  end

  def form_test_partials_path(name, context: nil)
    form_named_path(@configurator.project_test_partials_path, name)
  end

  def form_test_preprocess_includes_path(name, context: nil)
    form_named_path(@configurator.project_test_preprocess_includes_path, name)
  end

  def form_test_preprocess_files_path(name, context: nil)
    form_named_path(@configurator.project_test_preprocess_files_path, name)
  end

  def form_test_preprocess_files_full_expansion_path(name, context: nil)
    form_named_path(@configurator.project_test_preprocess_files_path, name, subdir: PREPROCESS_FULL_EXPANSION_DIR)
  end

  def form_test_preprocess_files_directives_only_path(name, context: nil)
    form_named_path(@configurator.project_test_preprocess_files_path, name, subdir: PREPROCESS_DIRECTIVES_ONLY_DIR)
  end

  def form_test_preprocess_files_raw_directives_only_path(name, context: nil)
    form_named_path(@configurator.project_test_preprocess_files_path, name, subdir: PREPROCESS_RAW_DIRECTIVES_ONLY_DIR)
  end

  def form_test_preprocess_build_directives_path(name, context: nil)
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

  # A flat test's own identity (no mirrored subdirectory of its own) forms the shared flat
  # runners directory, untouched -- only a genuinely nested test's own mirrored
  # subdirectory (excluding its own basename) becomes an extra directory level here, so two
  # same-named tests in different directories land in distinct runner directories without
  # perturbing the overwhelmingly common flat, non-duplicate case.
  def form_test_runners_path(name, context: nil)
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
    roots = @configurator.paths_source +
            @configurator.paths_support +
            @configurator.paths_include +
            @configurator.paths_test +
            generated_roots( test )

    subdir   = PathMirror.relative_subdir( filepath, roots )
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
    return mirror_build_objects(
      sources,
      root:  path,
      ext:   @configurator.extension_object.primary,
      roots: @configurator.paths_source + @configurator.paths_support + extra_roots
    )
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

  def form_pass_results_filelist(path, files)
    return mirror_build_objects(
      files,
      root:  path,
      ext:   @configurator.extension_testpass.primary,
      roots: @configurator.paths_test
    )
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

  # The mirrored-subdirectory portion of a test's own identity, excluding its own basename
  # -- '' for a flat test (e.g. 'TestFoo', no subdirectory at all), or the leading segments
  # for a nested one (e.g. 'unit' for 'unit/test_foo').
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
  def mirror_build_objects(files, root:, ext:, roots:)
    clean_roots = PathMirror.clean_roots( roots )

    objects = @file_wrapper.instantiate_file_list_literal(files).map do |file|
      subdir   = PathMirror.relative_subdir_from_clean_roots( file, clean_roots )
      basename = File.basename(file).ext(ext)
      subdir.empty? ? File.join(root, basename) : File.join(root, subdir, basename)
    end
    return @file_wrapper.instantiate_file_list_literal( objects )
  end

end
