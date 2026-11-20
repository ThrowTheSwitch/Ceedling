# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for adding ext() method to string
require 'ceedling/exceptions'
require 'ceedling/reportinator'
require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/path_mirror'
require 'ceedling/filesystem/file_path_utils'
require 'ceedling/filesystem/project_paths'
require 'ceedling/filesystem/build_subpath'

class FileFinder

  constructor :configurator, :file_finder_helper, :file_path_utils, :file_wrapper, :yaml_wrapper, :test_build_layout

  def setup
    @test_names_lock = Mutex.new
  end


  # `collection`, when given, is a test's HeaderSearch (see IncludePathinator#header_search),
  # which finds the header through that test's search paths as its compiler would, or a
  # caller's own ordered header list. Absent either, the project-wide collection_all_headers
  # is the fallback.
  # `complain` sets what a missing header does: :error raises, and :warn or :ignore
  # returns nil. A header matching only in letter case raises under all three; :silent
  # returns nil for that too.
  def find_header_input_for_mock(mock, collection: nil, complain: :error)
    found_path = @file_finder_helper.resolve_file_in_collection(
      mock_header_query(mock),
      collection || @configurator.collection_all_headers,
      complain
    )

    return found_path
  end

  # The header a mock's #include names, as in 'Mockfoo.h' or 'drivers/Mockfoo.h'. The mock
  # prefix drops from the filename alone, so the path the #include carried stays in the
  # query. A mock name may hold a dot (Sensor.44) by a versioning convention, so nothing
  # here assumes the name ends in an extension.
  def mock_header_query(mock)
    dir      = File.dirname(mock)
    basename = File.basename(mock).delete_prefix(@configurator.cmock_mock_prefix)
    return dir == '.' ? basename : File.join(dir, basename)
  end

  # A mock's real header and its own mirrored subdirectory below whichever configured
  # :test/:support/:include root contains it -- the same roots collection_all_headers is
  # built from. Combined into one call since every caller needing the mirrored subdirectory
  # also needs (or can reuse) the header path it was derived from, and every caller placing
  # a mock's own files -- its search path, an early stand-in for it, or its real generated
  # content -- must agree on exactly the same subdirectory for that mock to ever compile.
  # A missing header the caller tolerates through `complain` resolves to neither.
  def resolve_mock(mock, collection: nil, complain: :error)
    source = find_header_input_for_mock(mock, collection: collection, complain: complain)
    return [nil, nil] if source.nil?

    subdir = PathMirror.relative_subdir_from_clean_roots( source, @configurator.collection_mirror_roots_headers )
    return [source, subdir]
  end


  # Find test filepath from only the base name of a test file (e.g. 'test_foo')
  #
  # Deliberately strict, unlike every other lookup this class performs: a human typing
  # a `ceedling test:<name>` command needs to be told outright when their own name is
  # ambiguous, not have Ceedling silently guess which test they meant -- there's no
  # compilation step downstream to catch a wrong guess the way there is for a header
  # or source file resolved during a build.
  #
  # A task name is relative to the working directory, as every collected path is, so a
  # leading `..` names a test outside the project.
  def find_test_file_from_name(name)
    name = PathMatcher.resolve_relative(name, anchor: '')
    return find_first_candidate(name, @configurator.extension_source, @configurator.collection_all_tests, :error, strict: true)
  end


  def find_build_input_file(filepath:, complain: :error, context:, test: nil)
    release = (context == RELEASE_SYM)

    found_file = nil

    # Extract filename without file extension
    source_file = File.basename(filepath).ext('')

    # Recovered once and reused by every branch below that needs it. The caller's own test
    # comes first. Without one, a build file's own place in the test build layout names its
    # test exactly, and a source-tree query, from an #include or TEST_SOURCE_FILE(), names none.
    test_context = test ? test.to_s : test_context_of(filepath, context)

    # A test's generated mocks and Partials sit below its own roots, which only a known test
    # has. Without one these branches search nothing, so a query never finds another test's.
    mocks_root    = release ? nil : @test_build_layout.root( :mocks, test_context )
    partials_root = release ? nil : @test_build_layout.root( :partials, test_context )

    # We only collect files that already exist when we start up.
    # FileLists can produce undesired results for dynamically generated files depending on when they're accessed.
    # So collect mocks and runners separately and right now.
    # Assume that project configuration options will have already filtered out any files that should not be searched for.

    # Note: We carefully add file extensions below with string addition instead of using .ext()
    #       Some legacy files can include naming conventions like <name>.##.<ext> for versioning.
    #       If we use .ext() below we'll clobber the dotted portion of the filename

    # The name and the files a mock or Partial branch below searched. A hand-written source may
    # take a generated file's name, so a miss there falls through to the build's sources. A miss
    # of both complains of the generated file.
    generated = nil

    # Generated test runners -- searched for in the runners directory of this test's name,
    # so two same-named tests' runners are never mistaken for each other
    if (!release) and
       (source_file =~ /^#{Regexp.escape(@configurator.project_test_file_prefix)}.+#{Regexp.escape(@configurator.test_runner_file_suffix)}$/)
      _source_file = source_file + EXTENSION_CORE_SOURCE
      # #104 -- runner_scope_dir mirrors the test's own subdirectory, which may itself
      # contain a literal `[`/`]` (e.g. a test living directly under a bracket-named
      # directory); FilePathUtils.glob escapes it before Dir.glob (via directory_listing)
      # re-interprets it.
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing( FilePathUtils.glob(runner_scope_dir(test_context), '*') ),
          complain)

    # Generated mocks -- scoped to this test's own mock root so another test's
    # identically named mock (expected, routine repetition) is never mistaken for ambiguity
    elsif !mocks_root.nil? and
          (source_file.start_with?( @configurator.cmock_mock_prefix ))
      # A mock mirrors the directory of whatever it mocks, so two same-named headers
      # mocked in one test -- two modules mocked as Partials by directory, say -- are
      # told apart only by that subdirectory. Measured the same way a generated
      # Partial's is, below.
      subdir = generated_file_subdir( filepath, mocks_root, test: test_context, context: context )

      _source_file = source_file + EXTENSION_CORE_SOURCE
      _source_file = File.join( subdir, _source_file ) unless subdir.empty?
      collection   = own_generated_files( mocks_root )

      # The mock at exactly this place below the root comes first, since a same-named mock
      # deeper down, such as one an earlier build left, ends with the same folder and name.
      # A flat object path names no subdirectory, so the name alone still finds a mock
      # anywhere below the root.
      exact      = ProjectPaths.segments( File.join( mocks_root, _source_file ) )
      found_file = collection.find { |file| ProjectPaths.segments( file ) == exact }
      found_file ||= @file_finder_helper.find_file_in_collection( _source_file, collection, :ignore )
      generated  = [_source_file, collection]

    # Generated partials -- same per-test scoping rationale as mocks, above
    elsif !partials_root.nil? and
          (source_file.start_with?( PARTIAL_FILENAME_PREFIX ))
      # A generated Partial sits in the subdirectory mirroring its own module, so that
      # subdirectory is what distinguishes two modules sharing a basename. Derived the
      # same way a mock's is, above.
      subdir = generated_file_subdir( filepath, partials_root, test: test_context, context: context )

      _source_file = source_file + EXTENSION_CORE_SOURCE
      _source_file = File.join( subdir, _source_file ) unless subdir.empty?

      collection = own_generated_files( partials_root )

      # Ambiguity is detected here rather than rescued from the matching below. One
      # matching implementation stays in force, and the message is composed from the
      # module names the test author wrote instead of reworded by exception.
      raise_ambiguous_partial!( _source_file, collection, partials_root )

      found_file = @file_finder_helper.find_file_in_collection( _source_file, collection, :ignore )
      generated  = [_source_file, collection]

    # Vendor framework sources (unity.c, cmock.c, cexception.c, etc.)
    # Note: Taking a small chance by mixing test and release frameworks without smart checks on test/release build
    elsif (@configurator.collection_vendor_framework_sources.include?(source_file.ext(EXTENSION_CORE_SOURCE)))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_existing_test_build_input,
          complain)

    # The test file's own object resolves to the test it names. A name is the test's path,
    # so the lookup is exact. Searching by name instead is ambiguous wherever one test's
    # name ends another test's path.
    elsif (!release) and !test_context.empty? and (source_file == File.basename( test_context ))
      found_file = test_files_by_name[test_context]

    end

    if !found_file.nil?
      return found_file
    end

    #
    # Above, runners and vendor sources rely on the complain parameter passed to file_finder_helper,
    # since the kind of file sought is certain. Mocks and Partials complain only once the lookup
    # below misses too.
    #
    # Below we ignore file misses because of lgoical complexities of searching for potentially either
    # assmebly or C files, including C files that may not exist (counterparts to header files by convention).
    # We save the existence handling until the end.
    #

    # A module-under-test or release object sits at its source's own path below its build
    # root, so that path recovers the one source, rather than a bare basename that is
    # ambiguous the moment another same-named source exists elsewhere.
    query_file, exact = mirrored_query(filepath, release: release, test: test, context: context)

    found_file = find_compiled_input( query_file, release: release, exact: exact )

    if found_file.nil?
      # A generated file's search complains as it would alone, naming the file it sought
      return @file_finder_helper.find_file_in_collection( *generated, complain ) unless generated.nil?

      # Every name actually attempted, in the order tried, so a missing-file complaint
      # names every filename ceedling went looking for.
      tried = @configurator.extension_source.map { |ext| query_file + ext }
      tried += @configurator.extension_assembly.map { |ext| query_file + ext } if @configurator.release_build_use_assembly
      @file_finder_helper.handle_missing_file(tried.join(' or '), complain)
    end

    return found_file
  end


  # `collection`, when given, overrides collection_all_headers with a test's HeaderSearch or
  # a caller's own ordered header list -- see find_header_input_for_mock's comment.
  def find_header_file(filepath, complain = :error, collection: nil)
    return find_first_candidate(filepath, @configurator.extension_header, collection || @configurator.collection_all_headers, complain)
  end

  def find_source_file(filepath, complain = :error)
    return find_first_candidate(filepath, @configurator.extension_source, @configurator.collection_all_source, complain)
  end


  def find_assembly_file(filepath, complain = :error)
    return find_first_candidate(filepath, @configurator.extension_assembly, @configurator.collection_all_assembly, complain)
  end

  def find_file_from_list(filepath, file_list, complain)
    return @file_finder_helper.find_file_in_collection(filepath, file_list, complain)
  end

  ### Private ###

  private

  # A C or assembly build input for `query`, assembly first where the build uses it. An
  # exact query is the file's own path, matched as such before any tail match.
  def find_compiled_input(query, release:, exact:)
    collection = release ? @configurator.collection_release_build_input : @configurator.collection_existing_test_build_input

    compiled_extensions( release ).each do |extension|
      found = (exact && exact_file( query, extension, collection )) || try_extensions( query, extension, collection )
      return found unless found.nil?
    end

    return nil
  end

  def compiled_extensions(release)
    assembly = release ? @configurator.release_build_use_assembly : @configurator.test_build_use_assembly
    return assembly ? [@configurator.extension_assembly, @configurator.extension_source] : [@configurator.extension_source]
  end

  # Translates a generated-Partial ambiguity into the test author's own terms. The query
  # here is a generated filename under a build directory, neither of which the author
  # typed, so reporting them offers nothing to act on. Candidates render as extensionless
  # module paths -- exactly what a directive macro takes -- so one can be pasted straight
  # into the macro the message names.
  def raise_ambiguous_partial!(query, collection, root)
    candidates = PathMatcher.candidates( query, collection )

    return if candidates.length < 2

    _module = @file_path_utils.module_from_partial_filename( query )

    # Candidates arrive as paths below the generated Partials root for this test. The root
    # is Ceedling's own, so only the module's mirrored subdirectory below it means anything
    # to the author.
    modules = candidates.map do |candidate|
      @file_path_utils.module_from_partial_filename( candidate.delete_prefix( root + '/' ) )
    end.compact.uniq.sort

    # The hint only helps when a candidate actually has a directory to name.
    hint = modules.find { |candidate| File.dirname( candidate ) != '.' }

    message = Reportinator.generate_guidance(
      lead:     "Ambiguous Partial module reference '#{_module}' found.",
      notes:    modules,
      options:  [
        'Include more trailing path to distinguish among them.',
        ("Name one with a directory, e.g. TEST_PARTIAL_ALL_MODULE_AT(#{File.dirname( hint )}, #{File.basename( hint )})." unless hint.nil?)
      ],
      headings: { notes: 'CANDIDATES' }
    )

    raise CeedlingException.new( message )
  end

  # The name of the test whose own build directory holds `filepath` (TestBuildLayout#locate),
  # such as `test/unit/test_foo` for an object below `build/test/out/test/unit/test_foo/_t_/`.
  # It lets a lookup go straight to the one test a build file belongs to, rather than
  # searching the whole project by bare basename, the query shape that's ambiguous when
  # another same-named test exists elsewhere.
  #
  # A filepath below no test's own directory, such as a source-tree-relative query from an
  # #include or TEST_SOURCE_FILE(), has no test to recover and gives ''.
  def test_context_of(filepath, context)
    return @test_build_layout.locate( filepath, context: context ) || ''
  end

  # A test's runner lives where FilePathUtils#form_test_runners_path puts it. Takes the test
  # identity the caller already recovered rather than a raw filepath.
  def runner_scope_dir(test_context)
    return @file_path_utils.form_test_runners_path( test_context )
  end

  # Every test file by its name. Names are paths, and a build stops before its first lookup
  # if two tests in it share one. Built once, on first use, since build threads share this
  # finder.
  def test_files_by_name
    @test_names_lock.synchronize do
      @test_files_by_name ||= @configurator.collection_all_tests.to_h { |test| [@file_path_utils.form_test_name( test ), test.to_s] }
    end
  end

  # A test's generated mocks or Partials, below its own root of that kind. No other test's
  # root lies below it, so every file there is this test's own.
  def own_generated_files(root)
    return @file_wrapper.directory_listing( FilePathUtils.glob( root, '**/*' + EXTENSION_CORE_SOURCE ) )
  end

  # The query for the source of a release or module-under-test object, and whether it is
  # exact. Such an object sits at its source's own path below the release output root, or
  # below the build path of the test it belongs to, so decoding that path names the source.
  #
  # A filepath outside the build root is a source-tree-relative query in its own right,
  # from an #include or a TEST_SOURCE_FILE() directive, say. It keeps whatever path it
  # carries, reduced to its namespace below a configured include root when one contains it
  # (see header_root_relative_query below).
  #
  # A filepath below the build root in a context this method doesn't know (a plugin's own
  # object output, e.g. build/valgrind/out/...), or test build input queried without a test
  # identity, falls back to the bare basename.
  def mirrored_query(filepath, release:, test:, context:)
    return [source_tree_query( filepath ), false] unless ProjectPaths.contains?( @configurator.project_build_root, filepath )

    root     = placement_root( release, test, context )
    subdir   = root.nil? ? nil : ProjectPaths.subdir_below( root, File.dirname( filepath ) )
    basename = File.basename( filepath ).ext('')
    return [basename, false] if subdir.nil? || subdir.empty?

    # A marker no shortened root holds was placed by another configuration
    source_dir = BuildSubpath.decode( subdir, roots: @file_path_utils.build_roots, release: release )
    return [basename, false] if source_dir.nil?

    return [File.join( source_dir, basename ), true]
  end

  def source_tree_query(filepath)
    query = header_root_relative_query( filepath )
    return query.nil? ? filepath.ext('') : query
  end

  # The root a release or test object is placed below, or nil where none is known
  def placement_root(release, test, context)
    return @configurator.project_release_build_output_path if release

    return @test_build_layout.root( :out, test, context: context )
  end

  # The file of `collection` at exactly `query` plus one of `extension`'s spellings, or nil.
  # Compared by absolute path, through an index built once per collection, since build
  # threads share this finder.
  def exact_file(query, extension, collection)
    index = @test_names_lock.synchronize do
      (@exact_indexes ||= {}.compare_by_identity)[collection] ||= collection.to_h { |file| [ProjectPaths.absolute( file ), file.to_s] }
    end

    extension.to_a.each do |ext|
      found = index[ProjectPaths.absolute( query + ext )]
      return found unless found.nil?
    end

    return nil
  end

  # The subdirectory a generated file's query carries, mirroring the module it belongs to.
  #
  # Which root it sits below depends on who is asking. The generated #include carries the
  # root the file itself was written under; an object for that same file mirrors the
  # subdirectory below the test's own out root instead. Measuring against only one of the
  # two yields nothing for queries of the other kind, degrading them to a bare basename
  # that matches every same-named module in the test.
  #
  # Below neither root, the query is a synthesized name rather than a real file's path --
  # fallback preprocessing builds a generated #include from a module name instead of
  # resolving the file. Whatever directory such a name carries is the module's own.
  def generated_file_subdir(filepath, root, test:, context:)
    out_root = @test_build_layout.root( :out, test, context: context )

    subdir = PathMirror.relative_subdir( filepath, [root, out_root].compact )

    return subdir unless subdir.empty?

    return synthesized_relative_dir( filepath )
  end

  # The directory a synthesized generated-file name carries, or '' when it carries none.
  # Such a name is relative to nothing on disk, so its own dirname is all the module
  # context there is.
  def synthesized_relative_dir(filepath)
    dir  = File.dirname( filepath )
    root = @configurator.project_build_root

    return '' if dir == '.'

    # Compared as directories. A directory merely beginning with the build root's own name
    # is an ordinary relative directory and still names its module.
    return '' if ProjectPaths.contains?( root, dir )

    return dir
  end

  # A header's own path below its configured include root, or nil when no include root
  # contains it. Ceedling's convention correlates an #include'd header with the source
  # beside it, and the two trees routinely sit below different roots -- headers below
  # `include`, sources below `src`. The namespace they share below those roots is what
  # correlates them, so comparing the roots themselves only ever fails the match.
  #
  # Only the root is dropped. The namespace is preserved, since that is what keeps two
  # same-basename modules apart.
  def header_root_relative_query(filepath)
    subdir = PathMirror.relative_subdir_if_rooted_in_clean_roots( filepath, @configurator.collection_mirror_roots_include )

    return nil if subdir.nil?

    basename = File.basename( filepath ).ext('')

    return subdir.empty? ? basename : File.join( subdir, basename )
  end

  # A file type may be named by any one of several configured extensions, so a basename
  # alone doesn't say which candidate filename actually exists. Every candidate but the
  # last is searched for quietly by plain exact match -- a miss there just means trying
  # the next spelling, not a real problem, and critically, must not go through
  # find_file_in_collection/resolve_file_in_collection at all: that helper's own
  # case-insensitive "did you mean" fallback would otherwise fire on an early, expected
  # miss (trying `.s` before `.S`, say) the moment ANY differently-cased candidate
  # happens to exist on disk, well before every real candidate has had its turn. Only
  # the true last candidate is searched under the caller's own complain-on-miss
  # behavior, so a genuine failure still reports one sensible name -- and, in non-strict
  # mode, is the one place an ambiguity-resolution NOTICE gets logged (an ambiguity
  # among the quietly-tried earlier spellings resolves silently; extension collections
  # with only one configured spelling, the common case, always resolve via this last,
  # logged attempt anyway).
  #
  # `strict:` selects which of the two ambiguity policies every attempt uses: raise
  # (today's only behavior, still used by CLI test-name resolution) or resolve to the
  # first match by collection order (everything else).
  def find_first_candidate(query, extension, collection, complain, strict: false)
    candidates = extension.candidates(query)

    candidates[0...-1].each do |candidate|
      found = match_candidate(candidate, collection, strict: strict)
      return found unless found.nil?
    end

    if strict
      return @file_finder_helper.find_file_in_collection(candidates.last, collection, complain)
    else
      return @file_finder_helper.resolve_file_in_collection(candidates.last, collection, complain)
    end
  end

  # As `find_first_candidate`, but builds each candidate by plain string concatenation
  # rather than `String#ext` -- some legacy filenames carry a dotted version segment
  # (e.g. `foo.44`), and `.ext` would clobber that segment while re-adding the extension.
  # Mirrors find_first_candidate's quiet-until-the-last-spelling shape (see its own
  # comment) -- the caller decides how to react if no spelling is ever found.
  def try_extensions(basename, extension, collection, strict: false)
    exts = extension.to_a

    exts[0...-1].each do |ext|
      found = match_candidate(basename + ext, collection, strict: strict)
      return found unless found.nil?
    end

    last = basename + exts.last

    if strict
      return @file_finder_helper.find_file_in_collection(last, collection, :ignore)
    else
      return @file_finder_helper.resolve_file_in_collection(last, collection, :ignore)
    end
  end

  # A single candidate query, matched against `collection` via the shared path-aware
  # matcher. Strict mode raises on genuine ambiguity, exactly as today; non-strict mode
  # silently takes the first match by collection order with no log of its own -- this
  # quiet probe is for trying several candidate spellings in turn, not the caller's
  # real resolution attempt (see find_first_candidate/try_extensions).
  def match_candidate(candidate, collection, strict: false)
    if strict
      return PathMatcher.match(candidate, collection)
    else
      winner, _others = @file_finder_helper.resolve_in_collection(candidate, collection)
      return winner
    end
  end

end
