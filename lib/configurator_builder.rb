require 'rubygems'
require 'rake'            # for ext() method
require 'file_path_utils' # for form_vendor_path() class method
require 'constants'    # for Verbosity constants class


DEFAULT_INCLUDES_PREPROCESSOR_TOOL = {
  :executable => 'cpp',
  :name => 'includes_preprocessor',
  :arguments => [
    '-MM', '-MG',
    {"-D$" => 'COLLECTION_DEFINES_TEST'},        
    "\"${1}\""
    ]
  }

DEFAULT_FILE_PREPROCESSOR_TOOL = {
  :executable => 'gcc',
  :name => 'file_preprocessor',
  :arguments => [
    '-E',
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_AND_SOURCE_INCLUDE'},
    {"-D$" => 'COLLECTION_DEFINES_TEST'},        
    "\"${1}\"",
    "-o \"${2}\""
    ]
  }

DEFAULT_DEPENDENCIES_GENERATOR_TOOL = {
  :executable => 'gcc',
  :name => 'dependencies_generator',
  :arguments => [
    {"-I\"$\"" => 'COLLECTION_PATHS_TEST_AND_SOURCE_INCLUDE'},
    {"-D$" => 'COLLECTION_DEFINES_TEST'},        
    "-MT \"${3}\"",
    '-MM', '-MD', '-MG',
    "-MF \"${2}\"",
    "-c \"${1}\"",
    ]
  }

DEFAULT_CEEDLING_CONFIG = {
    :project_use_exceptions => true,
    :project_use_mocks => true,
    :project_use_preprocessor => false,
    :project_use_auxiliary_dependencies => false,
    :project_test_file_prefix => 'test_',
    :project_verbosity => Verbosity::NORMAL,

    :paths_support => [],
    :paths_include => [],
                   
    :defines_test => [],
    :defines_source => [],
                
    :extension_header => '.h',
    :extension_source => '.c',
    :extension_object => '.o',
    :extension_executable => '.out',
    :extension_testpass => '.pass',
    :extension_testfail => '.fail',
    :extension_dependencies => '.d',

    :unity_int_width => 32,
    :unity_exclude_float => false,
    :unity_float_type => 'float',    
    :unity_float_precision => '0.00001f',
                                        
    :test_runner_includes => [],
    :test_runner_file_suffix => '_runner',
    
    :tools_includes_preprocessor  => DEFAULT_INCLUDES_PREPROCESSOR_TOOL,
    :tools_file_preprocessor      => DEFAULT_FILE_PREPROCESSOR_TOOL,
    :tools_dependencies_generator => DEFAULT_DEPENDENCIES_GENERATOR_TOOL,
  }



class ConfiguratorBuilder
  
  constructor :project_file_loader, :file_system_utils, :file_wrapper
    
  
  def insert_tool_names(config)
    config[:tools].each_key do |name|
      tool = config[:tools][name]
      tool[:name] = name.to_s
    end
  end
  
  
  # create a flattened hash from the original configuration structure
  def hashify(config)
    hash = {}
    
    config.each_key do | parent |
      
      # gracefully handle empty top-level entries
      next if (config[parent].nil?)
      
      config[parent].each_pair do | child, value |
        key = "#{parent.to_s.downcase}_#{child.to_s.downcase}".to_sym
        hash[key] = value
      end
    end
    
    return hash
  end


  # set default values for those settings necessary for the project that a user may optionally overwrite in config file
  def populate_defaults(in_hash)
    # copy defaults hash in preparation for merging
    out_hash = DEFAULT_CEEDLING_CONFIG.clone
        
    # first, perform a simple deep merge of defaults hash with input hash
    out_hash.each_pair do |key, value|
      if (!in_hash[key].nil?)
        case(value)
          when Hash then out_hash[key].merge!(in_hash[key])
          else out_hash[key] = in_hash[key]
        end
      end
    end

    # second, copy into output hash anything unique that exists in input hash
    in_hash.each_pair do |key, value|
      out_hash[key] = value if (out_hash[key].nil?)
    end

    return out_hash
  end

  
  def clean(in_hash)
    # ensure that include files inserted into test runners have file extensions & proper ones at that
    in_hash[:test_runner_includes].map!{|include| include.ext(in_hash[:extension_header])}
  end


  def set_build_paths(in_hash)
    test_path = 'tests'
    release_path = 'release'
    build_paths = []
    out_hash = {}

    out_hash[:project_release_artifacts_path] = File.join(in_hash[:project_build_root], release_path, 'artifacts')
    out_hash[:project_release_build_output_path] = File.join(in_hash[:project_build_root], release_path, 'out')
    
    out_hash[:project_test_artifacts_path] = File.join(in_hash[:project_build_root], test_path, 'artifacts')
    out_hash[:project_test_runners_path] = File.join(in_hash[:project_build_root], test_path, 'runners')
    out_hash[:project_test_results_path] = File.join(in_hash[:project_build_root], test_path, 'results')
    out_hash[:project_test_build_output_path] = File.join(in_hash[:project_build_root], test_path, 'out')
    
    out_hash[:project_temp_path] = File.join(in_hash[:project_build_root], 'temp') if in_hash[:project_use_preprocessor]

    out_hash[:project_test_preprocess_includes_path] = File.join(in_hash[:project_build_root], test_path, 'preprocess/includes') if in_hash[:project_use_preprocessor]
    out_hash[:project_test_preprocess_files_path]    = File.join(in_hash[:project_build_root], test_path, 'preprocess/files')    if in_hash[:project_use_preprocessor]

    out_hash[:project_test_dependencies_path] = File.join(in_hash[:project_build_root], test_path, 'dependencies') if in_hash[:project_use_auxiliary_dependencies]

    # fetch already set mock path
    build_paths << in_hash[:cmock_mock_path] if in_hash[:project_use_mocks]
    
    out_hash.each_pair do |key, value|
      build_paths << out_hash[key]
    end

    out_hash[:project_build_paths] = build_paths

    return out_hash
  end


  def set_rakefile_components(in_hash)
    out_hash = {
      :project_rakefile_component_files => 
        [File.join(CEEDLING_LIB, 'tasks.rake'),
         File.join(CEEDLING_LIB, 'tasks_filesystem.rake'),
         File.join(CEEDLING_LIB, 'rules.rake')]}
    
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_cmock.rake') if (in_hash[:project_use_mocks])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_preprocess.rake') if (in_hash[:project_use_preprocessor])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_aux_dependencies.rake') if (in_hash[:project_use_auxiliary_dependencies])

    return out_hash
  end
  
  
  def collect_test_and_source_include_paths(in_hash)
    extra_paths = []
    insert_vendor_paths(extra_paths, in_hash)

    return {
      :paths_test_and_source_include => 
        in_hash[:paths_test] +
        in_hash[:paths_support] +
        in_hash[:paths_source] + 
        in_hash[:paths_include] + 
        extra_paths
      }    
  end

    
  def collect_test_and_source_paths(in_hash)
    extra_paths = []
    insert_vendor_paths(extra_paths, in_hash)
    extra_paths << in_hash[:project_test_runners_path]

    return {
      :paths_test_and_source => 
        in_hash[:paths_test] +
        in_hash[:paths_support] +
        in_hash[:paths_source] + 
        extra_paths
      }    
  end
  
  
  def collect_tests(in_hash)
    all_tests = @file_wrapper.instantiate_file_list
    
    in_hash[:paths_test].each do |path|
      all_tests.include( File.join(path, "#{in_hash[:project_test_file_prefix]}*#{in_hash[:extension_source]}") )
    end
    
    return {:collection_all_tests => all_tests}
  end


  def collect_source(in_hash)
    all_source = @file_wrapper.instantiate_file_list
    
    in_hash[:paths_source].each do |path|
      all_source.include( File.join(path, "*#{in_hash[:extension_source]}") )
    end
    
    return {:collection_all_source => all_source}
  end


  def collect_headers(in_hash)
    all_headers = @file_wrapper.instantiate_file_list
    
    paths = in_hash[:paths_support] + in_hash[:paths_source] + in_hash[:paths_include]
    
    (paths).each do |path|
      all_headers.include( File.join(path, "*#{in_hash[:extension_header]}") )
    end
    
    return {:collection_all_headers => all_headers}
  end


  def collect_all_compilation_input(in_hash)
    all_input = @file_wrapper.instantiate_file_list

    paths = 
      in_hash[:paths_test] + 
      in_hash[:paths_support] + 
      in_hash[:paths_source] + 
      in_hash[:paths_include]
    
    paths << in_hash[:project_test_runners_path]
    insert_vendor_paths(paths, in_hash)

    (paths).each do |path|
      all_input.include( File.join(path, "*#{in_hash[:extension_header]}") )
      all_input.include( File.join(path, "*#{in_hash[:extension_source]}") )
    end
    
    return {:collection_all_compilation_input => all_input}    
  end


  def collect_test_defines(in_hash)
    test_defines = in_hash[:defines_test]
    
    test_defines << "UNITY_INT_WIDTH=#{in_hash[:unity_int_width]}"
    
    if (in_hash[:unity_exclude_float])
      test_defines << 'UNITY_EXCLUDE_FLOAT'
    else
      test_defines << "UNITY_FLOAT_TYPE=#{in_hash[:unity_float_type]}"
      test_defines << "UNITY_FLOAT_PRECISION=#{in_hash[:unity_float_precision]}"
    end
    
    return {:collection_defines_test => test_defines}
  end


  # gather up all files that if changed should cause generated files on-disk to be regenerated
  def collect_environment_dependencies
    dependencies = []
    
    ceedling_build_file = File.join(CEEDLING_RELEASE, 'build.info')
    cmock_build_file    = File.join(CEEDLING_VENDOR, 'cmock/release', 'build.info')

    # project files: anything changes in them & everything should regenerate
    dependencies << @project_file_loader.main_project_filepath
    user_project_file = @project_file_loader.user_project_filepath
    dependencies << user_project_file if (not user_project_file.empty?)
    
    # ceedling itself: if it changes we gotta regenerate files
    dependencies << ceedling_build_file
    
    # cmock: same as ceedling
    dependencies << cmock_build_file
    
    # Note: since Unity and CException are C files, changes to them are noticed elsewhere

    out_hash = {
      :collection_environment_dependencies => dependencies
    }
    
    return out_hash
  end


  def expand_all_path_globs(in_hash)
    out_hash = {}
    path_keys = []
    
    # to provide assured order of traversal in test calls on mocks
    in_hash.each_key do |key|
      next if (not key.to_s[0..4] == 'paths')
      path_keys << key.to_s
    end
    
    path_keys.sort.each do |key|
      out_hash["collection_#{key}".to_sym] = @file_system_utils.collect_paths( in_hash[key.to_sym] )
    end
    
    
    return out_hash
  end
  
  private ##############################
  
  def insert_vendor_paths(paths, config)
    paths << FilePathUtils::form_ceedling_vendor_path('unity/src')
    paths << FilePathUtils::form_ceedling_vendor_path('c_exception/lib') if (config[:project_use_exceptions])
    paths << config[:cmock_mock_path] if (config[:project_use_mocks])
  end
  
end
