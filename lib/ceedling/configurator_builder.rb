# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake'                     # for ext() method
require 'ceedling/file_path_utils' # for class methods
require 'ceedling/defaults'
require 'ceedling/constants'       # for Verbosity constants class & base file paths

class ConfiguratorBuilder

  constructor :file_path_collection_utils, :file_wrapper, :system_wrapper


  def build_global_constant(elem, value)
    # Convert key names to Ruby constant names
    # Some key names can be C file names that can include dashes
    # Upcase the key names to create consitency and Ruby constants by convention
    # Replace dashes with underscores to match handling of Ruby accessor method names
    formatted_key = elem.to_s.gsub('-','_').upcase

    # Undefine global constant if it already exists
    Object.send(:remove_const, formatted_key.to_sym) if @system_wrapper.constants_include?(formatted_key)

    # Create global constant
    Object.module_eval("#{formatted_key} = value")
  end


  def build_global_constants(config)
    config.each_pair do |key, value|
      build_global_constant(key, value)
    end

    # TODO: This wants to go somewhere better
    Object.module_eval("TOOLS_TEST_ASSEMBLER = {}") if (not config[:test_build_use_assembly]) && !defined?(TOOLS_TEST_ASSEMBLER)
    Object.module_eval("TOOLS_RELEASE_ASSEMBLER = {}") if (not config[:release_build_use_assembly]) && !defined?(TOOLS_RELEASE_ASSEMBLER)
  end


  def build_accessor_methods(config, context)
    # Fill configurator object with accessor methods
    config.each_pair do |key, value|
      # Convert key names to Ruby method names
      # Some key names can be C file names that can include dashes; dashes are not allowed in Ruby method names
      # Downcase the key names and replace any illegal dashes with legal underscores
      # Downcased key names create consistency and ensure no method names become Ruby constants by accident
      eval("def #{key.to_s.gsub('-','_').downcase}() return @project_config_hash[:#{key}] end", context)
    end
  end


  # create a flattened hash from the original configuration structure
  def flattenify(config)
    new_hash = {}

    config.each_key do | parent |

      # Gracefully handle empty top-level entries
      next if (config[parent].nil?)

      case config[parent]
      when Array
        config[parent].each do |hash|
          key = "#{parent.to_s.downcase}_#{hash.keys[0].to_s.downcase}".to_sym
          new_hash[key] = hash[hash.keys[0]]
        end

      when Hash
        config[parent].each_pair do | child, value |
          key = "#{parent.to_s.downcase}_#{child.to_s.downcase}".to_sym
          new_hash[key] = value
        end

      # Handle entries with no children, only values
      else
        new_hash["#{parent.to_s.downcase}".to_sym] = config[parent]
      end

    end

    return new_hash
  end


  # If config lacks an entry present in defaults posseses, add the default entry
  # Processes recursively
  def populate_with_defaults(config, defaults)
    defaults.each do |key, value|
      # If config is missing the same key, copy in the default entry
      if config[key].nil?
        config[key] = value.is_a?(Hash) ? value.deep_clone : value

      # Continue recursively for hash entries
      elsif config[key].is_a?(Hash) && value.is_a?(Hash)
        populate_with_defaults(config[key], value)
      end
    end
  end


  def cleanup(in_hash)
    # Ensure that include files inserted into test runners have file extensions & proper ones at that
    in_hash[:test_runner_includes].map!{|include| include.ext(in_hash[:extension_header])}
  end


  def set_build_paths(in_hash, logging_path)
    out_hash = {}

    project_build_artifacts_root = File.join(in_hash[:project_build_root], 'artifacts')
    project_build_tests_root     = File.join(in_hash[:project_build_root], TESTS_BASE_PATH)
    project_build_vendor_root    = File.join(in_hash[:project_build_root], 'vendor')
    project_build_release_root   = File.join(in_hash[:project_build_root], RELEASE_BASE_PATH)

    paths = [
      [:project_build_artifacts_root,  project_build_artifacts_root, true ],
      [:project_build_tests_root,      project_build_tests_root,     true ],
      [:project_build_vendor_root,     project_build_vendor_root,    true ],
      [:project_build_release_root,    project_build_release_root,   in_hash[:project_release_build] ],

      [:project_test_artifacts_path,            File.join(project_build_artifacts_root, TESTS_BASE_PATH), true ],
      [:project_test_runners_path,              File.join(project_build_tests_root, 'runners'),           true ],
      [:project_test_results_path,              File.join(project_build_tests_root, 'results'),           true ],
      [:project_test_build_output_path,         File.join(project_build_tests_root, 'out'),               true ],
      [:project_test_build_cache_path,          File.join(project_build_tests_root, 'cache'),             true ],
      [:project_test_dependencies_path,         File.join(project_build_tests_root, 'dependencies'),      true ],

      [:project_build_vendor_unity_path,        File.join(project_build_vendor_root, 'unity', 'src'),       true ],
      [:project_build_vendor_cmock_path,        File.join(project_build_vendor_root, 'cmock', 'src'),       in_hash[:project_use_mocks] ],
      [:project_build_vendor_cexception_path,   File.join(project_build_vendor_root, 'c_exception', 'lib'), in_hash[:project_use_exceptions] ],

      [:project_release_artifacts_path,         File.join(project_build_artifacts_root, RELEASE_BASE_PATH), in_hash[:project_release_build] ],
      [:project_release_build_cache_path,       File.join(project_build_release_root, 'cache'),             in_hash[:project_release_build] ],
      [:project_release_build_output_path,      File.join(project_build_release_root, 'out'),               in_hash[:project_release_build] ],
      [:project_release_dependencies_path,      File.join(project_build_release_root, 'dependencies'),      in_hash[:project_release_build] ],

      [:project_log_path,                       logging_path, true ],

      [:project_test_preprocess_includes_path,  File.join(project_build_tests_root, 'preprocess/includes'), (in_hash[:project_use_test_preprocessor] != :none) ],
      [:project_test_preprocess_files_path,     File.join(project_build_tests_root, 'preprocess/files'),    (in_hash[:project_use_test_preprocessor] != :none) ],
    ]

    out_hash[:project_build_paths] = []

    # Fetch already set mock path
    out_hash[:project_build_paths] << in_hash[:cmock_mock_path] if (in_hash[:project_use_mocks])

    paths.each do |path|
      build_path_name          = path[0]
      build_path               = path[1]
      build_path_add_condition = path[2]

      # Insert path into build paths if associated with true condition
      out_hash[:project_build_paths] << build_path if build_path_add_condition
      # Set path symbol name and path for each entry in paths array
      out_hash[build_path_name] = build_path
    end

    return out_hash
  end


  def set_rakefile_components(ceedling_lib_path, in_hash)
    out_hash = {
      :project_rakefile_component_files => [
         File.join( ceedling_lib_path, 'tasks_base.rake' ),
         File.join( ceedling_lib_path, 'tasks_filesystem.rake' ),
         File.join( ceedling_lib_path, 'tasks_tests.rake' ),
         File.join( ceedling_lib_path, 'rules_tests.rake' )
         ]
      }

    out_hash[:project_rakefile_component_files] << File.join( ceedling_lib_path, 'rules_release.rake' ) if (in_hash[:project_release_build])
    out_hash[:project_rakefile_component_files] << File.join( ceedling_lib_path, 'tasks_release.rake' ) if (in_hash[:project_release_build])

    return out_hash
  end


  def set_release_target(in_hash)
    return {} if (not in_hash[:project_release_build])

    release_target_file = ((in_hash[:release_build_output].nil?) ? (DEFAULT_RELEASE_TARGET_NAME.ext(in_hash[:extension_executable])) : in_hash[:release_build_output])
    release_map_file    = ((in_hash[:release_build_output].nil?) ? (DEFAULT_RELEASE_TARGET_NAME.ext(in_hash[:extension_map])) : in_hash[:release_build_output].ext(in_hash[:extension_map]))

    return {
      # tempted to make a helper method in file_path_utils? stop right there, pal. you'll introduce a cyclical dependency
      :project_release_build_target => File.join(in_hash[:project_build_release_root], release_target_file),
      :project_release_build_map    => File.join(in_hash[:project_build_release_root], release_map_file)
      }
  end


  def set_build_thread_counts(in_hash)
    require 'etc'

    auto_thread_count = (Etc.nprocessors + 4)

    compile_threads = in_hash[:project_compile_threads]
    test_threads = in_hash[:project_test_threads]

    case compile_threads
    when Integer
      # Do nothing--value already validated
    when Symbol
      # If a symbol, it's already been validated as legal
      compile_threads = auto_thread_count if compile_threads == :auto
    end

    case test_threads
    when Integer
      # Do nothing--value already validated
    when Symbol
      # If a symbol, it's already been validated as legal
      test_threads = auto_thread_count if test_threads == :auto
    end

    return {
      :project_compile_threads => compile_threads,
      :project_test_threads => test_threads
    }
  end


  def set_test_preprocessor_accessors(in_hash)
    accessors = {}

    # :project_use_test_preprocessor already validated
    case in_hash[:project_use_test_preprocessor]
    when :none
      accessors = {
        :project_use_test_preprocessor_tests => false,
        :project_use_test_preprocessor_mocks => false
      }    
    when :all
      accessors = {
        :project_use_test_preprocessor_tests => true,
        :project_use_test_preprocessor_mocks => true
      }    
    when :tests
      accessors = {
        :project_use_test_preprocessor_tests => true,
        :project_use_test_preprocessor_mocks => false
      }    
    when :mocks
      accessors = {
        :project_use_test_preprocessor_tests => false,
        :project_use_test_preprocessor_mocks => true
      }    
    end

    return accessors
  end


  def expand_all_path_globs(in_hash)
    out_hash = {}
    path_keys = []

    in_hash.each_key do |key|
      next if (not key.to_s[0..4] == 'paths')
      path_keys << key
    end

    path_keys.each do |key|
      _collection = "collection_#{key}".to_sym
      out_hash[_collection] = @file_path_collection_utils.collect_paths( in_hash[key] )
    end

    return out_hash
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


  def collect_tests(in_hash)
    all_tests = @file_wrapper.instantiate_file_list

    in_hash[:collection_paths_test].each do |path|
      all_tests.include( File.join(path, "#{in_hash[:project_test_file_prefix]}*#{in_hash[:extension_source]}") )
    end

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    all_tests.resolve()

    return {
      # Add / subtract files via :files ↳ :test
      :collection_all_tests => @file_path_collection_utils.revise_filelist( all_tests, in_hash[:files_test] )
    }
  end


  def collect_assembly(in_hash)
    all_assembly = @file_wrapper.instantiate_file_list

    return {:collection_all_assembly => all_assembly} if ((not in_hash[:release_build_use_assembly]) && (not in_hash[:test_build_use_assembly]))

    # Sprinkle in all assembly files we can find in the source folders
    in_hash[:collection_paths_source].each do |path|
      all_assembly.include( File.join(path, "*#{in_hash[:extension_assembly]}") )
    end

    # Also add all assembly files we can find in the support folders
    in_hash[:collection_paths_support].each do |path|
      all_assembly.include( File.join(path, "*#{in_hash[:extension_assembly]}") )
    end

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    all_assembly.resolve()

    return {
      # Add / subtract files via :files ↳ :assembly
      :collection_all_assembly => @file_path_collection_utils.revise_filelist( all_assembly, in_hash[:files_assembly] )
    }

  end


  def collect_source(in_hash)
    all_source = @file_wrapper.instantiate_file_list

    in_hash[:collection_paths_source].each do |path|
      all_source.include( File.join(path, "*#{in_hash[:extension_source]}") )
    end

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    all_source.resolve()

    return {
      # Add / subtract files via :files ↳ :source
      :collection_all_source => @file_path_collection_utils.revise_filelist( all_source, in_hash[:files_source] )
    }
  end


  def collect_headers(in_hash)
    all_headers = @file_wrapper.instantiate_file_list

    paths =
      in_hash[:collection_paths_test] +
      in_hash[:collection_paths_support] +
      in_hash[:collection_paths_include]

    paths.each do |path|
      all_headers.include( File.join(path, "*#{in_hash[:extension_header]}") )
    end

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    all_headers.resolve()

    return {
      # Add / subtract files via :files ↳ :include
      :collection_all_headers => @file_path_collection_utils.revise_filelist( all_headers, in_hash[:files_include] )
    }
  end


  def collect_release_build_input(in_hash)
    release_input = @file_wrapper.instantiate_file_list

    paths = []
    paths << in_hash[:project_build_vendor_cexception_path] if (in_hash[:project_use_exceptions])

    # Collect vendor framework code files
    paths.each do |path|
      release_input.include( File.join(path, '*' + EXTENSION_CORE_SOURCE) )
    end

    # Collect source files
    in_hash[:collection_paths_source].each do |path|
      release_input.include( File.join(path, "*#{in_hash[:extension_source]}") )
      release_input.include( File.join(path, "*#{in_hash[:extension_assembly]}") ) if in_hash[:release_build_use_assembly]
    end

    # Add / subtract files via :files ↳ :source & :files ↳ :assembly
    revisions =  in_hash[:files_source]
    revisions += in_hash[:files_assembly] if in_hash[:release_build_use_assembly]

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    release_input.resolve()

    return {
      :collection_release_build_input => @file_path_collection_utils.revise_filelist( release_input, revisions )
    }
  end


  # Collect all test build code that exists in the configured paths (runners and mocks are handled at build time)
  def collect_existing_test_build_input(in_hash)
    all_input = @file_wrapper.instantiate_file_list

    # Vendor paths for frameworks
    paths = []
    paths << in_hash[:project_build_vendor_unity_path]
    paths << in_hash[:project_build_vendor_cexception_path] if (in_hash[:project_use_exceptions])
    paths << in_hash[:project_build_vendor_cmock_path]      if (in_hash[:project_use_mocks])

    # Collect vendor framework code files
    paths.each do |path|
      all_input.include( File.join(path, '*' + EXTENSION_CORE_SOURCE) )
    end

    paths =
      in_hash[:collection_paths_test] +
      in_hash[:collection_paths_support] +
      in_hash[:collection_paths_source]

    # Collect code files
    paths.each do |path|
      all_input.include( File.join(path, "*#{in_hash[:extension_source]}") )
      all_input.include( File.join(path, "*#{in_hash[:extension_assembly]}") ) if in_hash[:test_build_use_assembly]
    end

    # Add / subtract files via :files entries
    revisions =  in_hash[:files_test]
    revisions += in_hash[:files_support]
    revisions += in_hash[:files_source]
    revisions += in_hash[:files_assembly] if in_hash[:test_build_use_assembly]

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    all_input.resolve()

    return {
      :collection_existing_test_build_input => @file_path_collection_utils.revise_filelist( all_input, revisions )
    }
  end


  def collect_release_artifact_extra_link_objects(in_hash)
    objects = []

    # no build paths here so plugins can remap if necessary (i.e. path mapping happens at runtime)
    objects << CEXCEPTION_C_FILE.ext( in_hash[:extension_object] ) if (in_hash[:project_use_exceptions])

    return {:collection_release_artifact_extra_link_objects => objects}
  end


  def collect_test_fixture_extra_link_objects(in_hash)
    sources = []
    support = @file_wrapper.instantiate_file_list()

    paths = in_hash[:collection_paths_support]

    # Collect code files
    paths.each do |path|
      support.include( File.join(path, "*#{in_hash[:extension_source]}") )
      support.include( File.join(path, "*#{in_hash[:extension_assembly]}") ) if in_hash[:test_build_use_assembly]
    end

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    support.resolve()

    support = @file_path_collection_utils.revise_filelist( support, in_hash[:files_support] )

    support.each { |file| sources << file }

    # Create object files from all the sources
    objects = sources.map { |file| File.basename(file) }

    # No build paths here so plugins can remap if necessary (i.e. path mapping happens at runtime)
    objects.map! { |object| object.ext(in_hash[:extension_object]) }

    return { 
      :collection_all_support => sources,
      :collection_test_fixture_extra_link_objects => objects
    }
  end


  # .c files without path
  def collect_vendor_framework_sources(in_hash)
    sources = []
    filelist = @file_wrapper.instantiate_file_list()

    # Vendor paths for frameworks
    paths = get_vendor_paths(in_hash)

    # Collect vendor framework code files
    paths.each do |path|
      filelist.include( File.join(path, '*' + EXTENSION_CORE_SOURCE) )
    end

    # Force Rake::FileList to expand patterns to ensure it happens (FileList is a bit unreliable)
    filelist.resolve()

    # Extract just source file names
    filelist.each do |filepath|
      sources << File.basename(filepath)
    end

    return {:collection_vendor_framework_sources => sources}
  end


  ### Private ###

  private

  def get_vendor_paths(in_hash)
    vendor_paths = []
    vendor_paths << in_hash[:project_build_vendor_unity_path]
    vendor_paths << in_hash[:project_build_vendor_cmock_path]       if (in_hash[:project_use_mocks])
    vendor_paths << in_hash[:project_build_vendor_cexception_path]  if (in_hash[:project_use_exceptions])

    return vendor_paths
  end

end
