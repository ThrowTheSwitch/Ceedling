# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake'                     # for ext() method
require 'ceedling/file_path_utils' # for class methods
require 'ceedling/defaults'
require 'ceedling/constants'       # for Verbosity constants class & base file paths
require 'ceedling/filename_extension'
require 'ceedling/rake_app/rakefile_component_resolver'

class ConfiguratorBuilder

  constructor :file_path_collection_utils, :loginator, :file_wrapper, :system_wrapper

  # Which of tests and mocks each :use_test_preprocessor option preprocesses
  TEST_PREPROCESSING = {
    none:  [false, false],
    all:   [true,  true],
    tests: [true,  false],
    mocks: [false, true]
  }.freeze

  # Global configuration constants are defined in this namespace. A build reads them from
  # Object. A spec supplies a throwaway module instead.
  attr_writer :constants_namespace

  def setup
    @constants_namespace = Object
  end


  # A constant is its key upcased. A key can be a C file name, whose dashes become underscores.
  def build_global_constant(elem, value)
    name = elem.to_s.tr( '-', '_' ).upcase

    @constants_namespace.send( :remove_const, name ) if @constants_namespace.const_defined?( name, false )
    @constants_namespace.const_set( name, value )
  end


  # Rakefiles reference both assembler tool constants, so a build that does not assemble
  # gets an empty tool definition
  def build_global_constants(config)
    config.each_pair { |key, value| build_global_constant( key, value ) }

    [ [:TOOLS_TEST_ASSEMBLER, :test_build_use_assembly], [:TOOLS_RELEASE_ASSEMBLER, :release_build_use_assembly] ].each do |name, assembly|
      @constants_namespace.const_set( name, {} ) unless config[assembly] || @constants_namespace.const_defined?( name, false )
    end
  end


  # Each accessor is the key downcased, defined on `target` alone, and reads the target's
  # project configuration. A key can be a C file name, whose dashes become underscores.
  def build_accessor_methods(config, target)
    config.each_key do |key|
      target.define_singleton_method( key.to_s.tr( '-', '_' ).downcase ) { @project_config_hash[key] }
    end
  end


  # Flattens each section's entries into top-level keys named <section>_<entry>. A section
  # holding a list, such as :environment, flattens each single-pair hash in it. A section
  # holding a plain value keeps its own name, and an empty section is skipped.
  def flattenify(config)
    return config.each_with_object( {} ) do |(section, value), flattened|
      flattened.merge!( flatten_section( section.to_s.downcase, value ) )
    end
  end


  # If config lacks an entry present in defaults, add the default entry. Processes recursively.
  #
  # A default is cloned whatever its type. Plugin defaults are often frozen literals, and
  # later steps such as path standardization change values in place, so every value must
  # be the configuration's own copy.
  def populate_with_defaults(config, defaults)
    defaults.each do |key, value|
      if config[key].nil?
        config[key] = value.deep_clone
      elsif config[key].is_a?(Hash) && value.is_a?(Hash)
        populate_with_defaults(config[key], value)
      end
    end
  end


  # Every :extension entry, a single extension or a list, becomes a FilenameExtension, so
  # the rest of the build handles one interface for a file type's extensions
  def normalize_filename_extensions(config)
    return if config[:extension].nil?

    config[:extension].transform_values! { |value| FilenameExtension.new( value ) }
  end


  # Every build path, beneath the build root, and the list of those to create. A path is
  # created only when the feature using it is configured.
  def set_build_paths(in_hash, logging_path)
    paths = build_path_table( in_hash, logging_path )

    out_hash = paths.to_h { |name, path, _| [name, path] }

    # The mock path is already set
    mocks = in_hash[:project_use_mocks] ? [in_hash[:cmock_mock_path]] : []
    out_hash[:project_build_paths] = mocks + paths.select { |_, _, create| create }.map { |_, path, _| path }

    return out_hash
  end


  def set_rakefile_components(ceedling_lib_path, in_hash)
    out_hash = {
      :project_rakefile_component_files =>
        ( RakefileComponentResolver.base_rakefiles( ceedling_lib_path ) +
          RakefileComponentResolver.test_rakefiles( ceedling_lib_path )
        )
      }

    if (in_hash[:project_release_build])
      out_hash[:project_rakefile_component_files] += RakefileComponentResolver.release_rakefiles( ceedling_lib_path )
    end

    return out_hash
  end


  # A release is named by :release_build ↳ :output, or by default and the executable
  # extension. Its map file shares its name.
  def set_release_target(in_hash)
    return {} if (not in_hash[:project_release_build])

    output = in_hash[:release_build_output]
    target = output || DEFAULT_RELEASE_TARGET_NAME.ext( in_hash[:extension_executable].primary )
    map    = (output || DEFAULT_RELEASE_TARGET_NAME).ext( in_hash[:extension_map].primary )

    # tempted to make a helper method in file_path_utils? stop right there, pal. you'll introduce a cyclical dependency
    root = in_hash[:project_build_release_root]
    return { project_release_build_target: File.join( root, target ), project_release_build_map: File.join( root, map ) }
  end


  # :auto resolves to the processor count plus four. A count was validated earlier.
  def set_build_thread_counts(in_hash)
    auto = @system_wrapper.processor_count + 4

    return {
      :project_compile_threads => resolve_threads( in_hash[:project_compile_threads], auto ),
      :project_test_threads    => resolve_threads( in_hash[:project_test_threads], auto )
    }
  end


  # :project_use_test_preprocessor already validated
  def set_test_preprocessor_accessors(in_hash)
    tests, mocks = TEST_PREPROCESSING[in_hash[:project_use_test_preprocessor]]

    return { :project_use_test_preprocessor_tests => tests, :project_use_test_preprocessor_mocks => mocks }
  end


  # Every :paths entry becomes a collection of the directories its globs name
  def expand_all_path_globs(in_hash)
    path_keys = in_hash.keys.select { |key| key.to_s.start_with?( 'paths' ) }

    return path_keys.to_h { |key| [:"collection_#{key}", @file_path_collection_utils.collect_paths( in_hash[key] )] }
  end


  def collect_source_and_include_paths(in_hash)
    return {
      :collection_paths_source_and_include =>
        ( in_hash[:collection_paths_source] +
          in_hash[:collection_paths_include] )
      }
  end


  def collect_source_include_vendor_paths(in_hash)
    extra_paths = []
    extra_paths <<  in_hash[:project_build_vendor_cexception_path] if (in_hash[:project_use_exceptions])
    extra_paths <<  in_hash[:project_build_vendor_ceedling_path] if (in_hash[:project_use_partials])

    return {
      :collection_paths_source_include_vendor =>
        in_hash[:collection_paths_source_and_include] +
        extra_paths
      }
  end


  def collect_test_support_source_include_paths(in_hash)
    return {
      :collection_paths_test_support_source_include =>
        ( in_hash[:collection_paths_test] +
          in_hash[:collection_paths_support] +
          in_hash[:collection_paths_source] +
          in_hash[:collection_paths_include] )
      }
  end


  def collect_vendor_paths(in_hash)
    return {:collection_paths_vendor => get_vendor_paths(in_hash)}
  end


  def collect_test_support_source_include_vendor_paths(in_hash)
    return {
      :collection_paths_test_support_source_include_vendor =>
        get_vendor_paths(in_hash) +
        in_hash[:collection_paths_test_support_source_include]
      }
  end


  # A test file's basename carries the project's test-file prefix ahead of a source
  # extension. Returns the collection and also the list of tests, which collect_source
  # filters out of the sources.
  def collect_tests(in_hash)
    prefix   = in_hash[:project_test_file_prefix]
    patterns = in_hash[:collection_paths_test].flat_map do |path|
      in_hash[:extension_source].map { |ext| FilePathUtils.glob( path, "#{prefix}*#{ext}" ) }
    end

    # Add / subtract files via :files ↳ :test
    tests = file_collection( patterns, in_hash[:files_test] )
    return { :collection_all_tests => tests }, tests
  end


  # Assembly files in source and support paths, if either build assembles
  def collect_assembly(in_hash)
    if (not in_hash[:release_build_use_assembly]) && (not in_hash[:test_build_use_assembly])
      return { :collection_all_assembly => @file_wrapper.instantiate_file_list }
    end

    paths = in_hash[:collection_paths_source] + in_hash[:collection_paths_support]

    # Add / subtract files via :files ↳ :assembly
    return { :collection_all_assembly => file_collection( code_patterns( paths, in_hash[:extension_assembly] ), in_hash[:files_assembly] ) }
  end


  # Source files, less any test files that overlapping test and source paths also matched
  def collect_source(in_hash, test_list)
    sources = file_list( code_patterns( in_hash[:collection_paths_source], in_hash[:extension_source] ) )

    mixed_in = test_list.select { |test| sources.include?( test ) }
    exclude_tests( sources, mixed_in ) unless mixed_in.empty?

    # Add / subtract files via :files ↳ :source
    return { :collection_all_source => @file_path_collection_utils.revise_filelist( sources, in_hash[:files_source] ) }
  end


  def collect_headers(in_hash)
    paths = in_hash[:collection_paths_test] + in_hash[:collection_paths_support] + in_hash[:collection_paths_include]

    # Add / subtract files via :files ↳ :include
    return { :collection_all_headers => file_collection( code_patterns( paths, in_hash[:extension_header] ), in_hash[:files_include] ) }
  end


  # Source files, plus CException's when exceptions are in use and assembly files when the
  # release build assembles
  def collect_release_build_input(in_hash)
    assembly = in_hash[:release_build_use_assembly]
    vendor   = in_hash[:project_use_exceptions] ? [in_hash[:project_build_vendor_cexception_path]] : []
    patterns = vendor_patterns( vendor ) + code_patterns( in_hash[:collection_paths_source], *code_extensions( in_hash, assembly ) )

    # Add / subtract files via :files ↳ :source & :files ↳ :assembly
    revisions = in_hash[:files_source] + (assembly ? in_hash[:files_assembly] : [])
    return { :collection_release_build_input => file_collection( patterns, revisions ) }
  end


  # Collect all test build code that exists in the configured paths (runners and mocks are handled at build time)
  def collect_existing_test_build_input(in_hash)
    assembly = in_hash[:test_build_use_assembly]
    paths    = in_hash[:collection_paths_test] + in_hash[:collection_paths_support] + in_hash[:collection_paths_source]
    patterns = vendor_patterns( test_vendor_paths( in_hash ) ) + code_patterns( paths, *code_extensions( in_hash, assembly ) )

    return { :collection_existing_test_build_input => file_collection( patterns, test_build_revisions( in_hash, assembly ) ) }
  end


  def collect_release_artifact_extra_link_objects(in_hash)
    objects = []

    # no build paths here so plugins can remap if necessary (i.e. path mapping happens at runtime)
    objects << CEXCEPTION_C_FILE.ext( in_hash[:extension_object].primary ) if (in_hash[:project_use_exceptions])

    return {:collection_release_artifact_extra_link_objects => objects}
  end


  # Every support file is linked into every test fixture. Object names carry no build path,
  # so plugins can remap them at runtime.
  def collect_test_fixture_extra_link_objects(in_hash)
    extensions = code_extensions( in_hash, in_hash[:test_build_use_assembly] )
    patterns   = code_patterns( in_hash[:collection_paths_support], *extensions )

    # Add / subtract files via :files ↳ :support
    sources = file_collection( patterns, in_hash[:files_support] ).to_a
    objects = sources.map { |file| File.basename( file ).ext( in_hash[:extension_object].primary ) }

    return { :collection_all_support => sources, :collection_test_fixture_extra_link_objects => objects }
  end


  # .c files without path
  def collect_vendor_framework_sources(in_hash)
    sources = file_list( vendor_patterns( get_vendor_paths( in_hash ) ) ).map { |filepath| File.basename( filepath ) }

    return { :collection_vendor_framework_sources => sources }
  end


  ### Private ###

  private

  def flatten_section(section, value)
    case value
    when nil   then {}
    when Array then value.to_h { |pair| [:"#{section}_#{pair.keys[0].to_s.downcase}", pair.values[0]] }
    when Hash  then value.to_h { |entry, entry_value| [:"#{section}_#{entry.to_s.downcase}", entry_value] }
    else { section.to_sym => value }
    end
  end

  # Each build path as [name, path, whether to create it]
  def build_path_table(in_hash, logging_path)
    build_root = in_hash[:project_build_root]
    artifacts  = File.join( build_root, 'artifacts' )

    return [
      [:project_build_artifacts_root,          artifacts,                                  true ],
      [:project_test_artifacts_path,           File.join( artifacts, TESTS_BASE_PATH ),    true ],
      [:project_log_path,                      logging_path,                               true ],
      [:project_build_dependencies_cache_path, File.join( build_root, 'cache' ),           true ]
    ] + test_build_paths( in_hash ) + vendor_build_paths( in_hash ) + release_build_paths( in_hash, artifacts )
  end

  def test_build_paths(in_hash)
    tests_root = File.join( in_hash[:project_build_root], TESTS_BASE_PATH )

    return [ [:project_build_tests_root, tests_root, true] ] + {
      :project_test_runners_path      => ['runners',      true ],
      :project_test_results_path      => ['results',      true ],
      :project_test_build_output_path => ['out',          true ],
      :project_test_build_cache_path  => ['cache',        true ],
      :project_test_dependencies_path => ['dependencies', true ],
      :project_test_partials_path     => ['partials',     in_hash[:project_use_partials] ]
    }.map { |name, (dir, create)| [name, File.join( tests_root, dir ), create] } + test_preprocess_paths( in_hash, tests_root )
  end

  # A test file's own build directive macros (TEST_INCLUDE_PATH(), TEST_SOURCE_FILE()) are
  # cached whether or not preprocessing is enabled
  def test_preprocess_paths(in_hash, tests_root)
    preprocessing = in_hash[:project_use_test_preprocessor] != :none

    return [
      [:project_test_preprocess_includes_path,         File.join( tests_root, 'preprocess/includes' ),         preprocessing ],
      [:project_test_preprocess_files_path,            File.join( tests_root, 'preprocess/files' ),            preprocessing ],
      [:project_test_preprocess_build_directives_path, File.join( tests_root, 'preprocess/build_directives' ), true ]
    ]
  end

  # A Ceedling vendor path is always present, even if empty, since certain preprocessing
  # steps need it as a search path
  def vendor_build_paths(in_hash)
    vendor_root = File.join( in_hash[:project_build_root], 'vendor' )

    return [ [:project_build_vendor_root, vendor_root, true] ] + {
      :project_build_vendor_unity_path      => ['unity/src',       true ],
      :project_build_vendor_ceedling_path   => ['ceedling',        true ],
      :project_build_vendor_cmock_path      => ['cmock/src',       in_hash[:project_use_mocks] ],
      :project_build_vendor_cexception_path => ['c_exception/lib', in_hash[:project_use_exceptions] ]
    }.map { |name, (dir, create)| [name, File.join( vendor_root, dir ), create] }
  end

  def release_build_paths(in_hash, artifacts)
    release      = in_hash[:project_release_build]
    release_root = File.join( in_hash[:project_build_root], RELEASE_BASE_PATH )

    return [
      [:project_build_release_root,        release_root,                                 release ],
      [:project_release_artifacts_path,    File.join( artifacts, RELEASE_BASE_PATH ),    release ],
      [:project_release_build_cache_path,  File.join( release_root, 'cache' ),           release ],
      [:project_release_build_output_path, File.join( release_root, 'out' ),             release ],
      [:project_release_dependencies_path, File.join( release_root, 'dependencies' ),    release ]
    ]
  end

  def resolve_threads(threads, auto)
    return (threads == :auto) ? auto : threads
  end

  def get_vendor_paths(in_hash)
    vendor_paths = []
    vendor_paths << in_hash[:project_build_vendor_unity_path]
    vendor_paths << in_hash[:project_build_vendor_cmock_path]       if (in_hash[:project_use_mocks])
    vendor_paths << in_hash[:project_build_vendor_cexception_path]  if (in_hash[:project_use_exceptions])
    vendor_paths << in_hash[:project_build_vendor_ceedling_path]    if (in_hash[:project_use_partials])

    return vendor_paths
  end

  # The framework code a test build compiles from the vendor directory
  def test_vendor_paths(in_hash)
    paths = [in_hash[:project_build_vendor_unity_path]]
    paths << in_hash[:project_build_vendor_cexception_path] if in_hash[:project_use_exceptions]
    paths << in_hash[:project_build_vendor_cmock_path]      if in_hash[:project_use_mocks]

    return paths
  end

  # Add / subtract files via the :files entries a test build compiles
  def test_build_revisions(in_hash, assembly)
    return in_hash[:files_test] + in_hash[:files_support] + in_hash[:files_source] + (assembly ? in_hash[:files_assembly] : [])
  end

  # Source extensions, plus assembly extensions for a build that assembles
  def code_extensions(in_hash, assembly)
    return [in_hash[:extension_source]] + (assembly ? [in_hash[:extension_assembly]] : [])
  end

  # A glob for each extension in each path, path by path
  def code_patterns(paths, *extensions)
    return paths.flat_map { |path| extensions.flat_map { |extension| extension.glob_patterns( path ) } }
  end

  # #104 -- a vendor path is rooted at the project directory, which may sit beneath a
  # bracket-named directory. FilePathUtils.glob escapes the brackets.
  def vendor_patterns(paths)
    return paths.map { |path| FilePathUtils.glob( path, '*' + EXTENSION_CORE_SOURCE ) }
  end

  # Files matching `patterns`, revised by a :files list of additions and removals
  def file_collection(patterns, revisions)
    return @file_path_collection_utils.revise_filelist( file_list( patterns ), revisions )
  end

  # FileList expands its patterns lazily, so they are expanded here
  def file_list(patterns)
    list = @file_wrapper.instantiate_file_list
    list.include( *patterns )
    return list.resolve()
  end

  def exclude_tests(sources, tests)
    sources.exclude( *tests )
    @loginator.log(
      "Test file paths and source file paths overlap -- test files have been filtered out of the source file collection",
      Verbosity::COMPLAIN
    )
  end

end
