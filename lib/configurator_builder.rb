require 'rubygems'
require 'rake'            # for ext() method
require 'file_path_utils' # for class methods
require 'defaults'
require 'constants'       # for Verbosity constants class & base file paths



class ConfiguratorBuilder
  
  constructor :project_config_manager, :file_system_utils, :file_wrapper
    
  
  def build_global_constants(config)
    config.each_pair do |key, value|
      formatted_key = key.to_s.upcase
      # undefine global constant if it already exists
      Object.send(:remove_const, formatted_key.to_sym) if Object.constants.include?(formatted_key)
      # create global constant
      Object.module_eval("#{formatted_key} = value")
    end
  end

  
  def build_accessor_methods(config, context)
    config.each_pair do |key, value|
      # fill configurator object with accessor methods
      eval("def #{key.to_s.downcase}() return @project_config_hash[:#{key.to_s}] end", context)
    end
  end

  
  # create a flattened hash from the original configuration structure
  def flattenify(config)
    new_hash = {}
    
    config.each_key do | parent |

      # gracefully handle empty top-level entries
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
      # handle entries with no children, only values
      else
        new_hash["#{parent.to_s.downcase}".to_sym] = config[parent]
      end
      
    end
    
    return new_hash
  end

  
  def populate_default_test_tools(config, new_config)
    new_config[:tools][:test_compiler] = DEFAULT_TEST_COMPILER_TOOL if (config[:tools].nil? or config[:tools][:test_compiler].nil?)
    new_config[:tools][:test_linker]   = DEFAULT_TEST_LINKER_TOOL   if (config[:tools].nil? or config[:tools][:test_linker].nil?)
    new_config[:tools][:test_fixture]  = DEFAULT_TEST_FIXTURE_TOOL  if (config[:tools].nil? or config[:tools][:test_fixture].nil?)
  end
  
  
  def populate_default_test_helper_tools(config, new_config)
    use_test_preprocessor = (( config[:project].nil? or config[:project][:use_test_preprocessor].nil? or (config[:project][:use_test_preprocessor] == false) ) ? false : true )
    use_aux_dependencies  = (( config[:project].nil? or config[:project][:use_auxiliary_dependencies].nil? or (config[:project][:use_auxiliary_dependencies] == false) ) ? false : true )
    
    new_config[:tools][:test_includes_preprocessor]  = DEFAULT_TEST_INCLUDES_PREPROCESSOR_TOOL   if (use_test_preprocessor and (config[:tools].nil? or config[:tools][:test_includes_preprocessor].nil?))
    new_config[:tools][:test_file_preprocessor]      = DEFAULT_TEST_FILE_PREPROCESSOR_TOOL       if (use_test_preprocessor and (config[:tools].nil? or config[:tools][:test_file_preprocessor].nil?))
    new_config[:tools][:test_dependencies_generator] = DEFAULT_TEST_DEPENDENCIES_GENERATOR_TOOL  if (use_aux_dependencies and (config[:tools].nil? or config[:tools][:test_dependencies_generator].nil?))
  end


  def populate_default_release_tools(config, new_config)
    release_build         = (( config[:project].nil? or config[:project][:release_build].nil? or (config[:project][:release_build] == false) ) ? false : true )
    use_aux_dependencies  = (( config[:project].nil? or config[:project][:use_auxiliary_dependencies].nil? or (config[:project][:use_auxiliary_dependencies] == false) ) ? false : true )
    use_assembly          = (( config[:release_build].nil? or config[:release_build][:use_assembly].nil? or (config[:release_build][:use_assembly] == false) ) ? false : true )
        
    new_config[:tools][:release_compiler]               = DEFAULT_RELEASE_COMPILER_TOOL                if (release_build and (config[:tools].nil? or config[:tools][:release_compiler].nil?))
    new_config[:tools][:release_assembler]              = DEFAULT_RELEASE_ASSEMBLER_TOOL               if (release_build and use_assembly and (config[:tools].nil? or config[:tools][:release_assembler].nil?))
    new_config[:tools][:release_linker]                 = DEFAULT_RELEASE_LINKER_TOOL                  if (release_build and (config[:tools].nil? or config[:tools][:release_linker].nil?))
    new_config[:tools][:release_dependencies_generator] = DEFAULT_RELEASE_DEPENDENCIES_GENERATOR_TOOL  if (release_build and use_aux_dependencies and (config[:tools].nil? or config[:tools][:release_dependencies_generator].nil?))
  end
  
  
  def clean(in_hash)
    # ensure that include files inserted into test runners have file extensions & proper ones at that
    in_hash[:test_runner_includes].map!{|include| include.ext(in_hash[:extension_header])}
  end


  def set_build_paths(in_hash)
    out_hash = {}

    project_build_artifacts_root = File.join(in_hash[:project_build_root], 'artifacts')
    project_build_tests_root     = File.join(in_hash[:project_build_root], TESTS_BASE_PATH)
    project_build_release_root   = File.join(in_hash[:project_build_root], RELEASE_BASE_PATH)

    paths = [
      [:project_build_artifacts_root,  project_build_artifacts_root, true ],
      [:project_build_tests_root,      project_build_tests_root,     true ],
      [:project_build_release_root,    project_build_release_root,   in_hash[:project_release_build] ],

      [:project_test_artifacts_path,     File.join(project_build_artifacts_root, TESTS_BASE_PATH), true ],
      [:project_test_runners_path,       File.join(project_build_tests_root, 'runners'),           true ],
      [:project_test_results_path,       File.join(project_build_tests_root, 'results'),           true ],
      [:project_test_build_output_path,  File.join(project_build_tests_root, 'out'),               true ],
      [:project_test_build_cache_path,   File.join(project_build_tests_root, 'cache'),             true ],

      [:project_release_artifacts_path,         File.join(project_build_artifacts_root, RELEASE_BASE_PATH), in_hash[:project_release_build] ],
      [:project_release_build_cache_path,       File.join(project_build_release_root, 'cache'),             in_hash[:project_release_build] ],
      [:project_release_build_output_path,      File.join(project_build_release_root, 'out'),               in_hash[:project_release_build] ],
      [:project_release_build_output_asm_path,  File.join(project_build_release_root, 'out', 'asm'),        in_hash[:project_release_build] ],
      [:project_release_build_output_c_path,    File.join(project_build_release_root, 'out', 'c'),          in_hash[:project_release_build] ],
      [:project_release_dependencies_path,      File.join(project_build_release_root, 'dependencies'),      in_hash[:project_release_build] && in_hash[:project_use_auxiliary_dependencies] ],

      [:project_log_path,   File.join(in_hash[:project_build_root], 'logs'), true ],
      [:project_temp_path,  File.join(in_hash[:project_build_root], 'temp'), true ],

      [:project_test_preprocess_includes_path,  File.join(project_build_tests_root, 'preprocess/includes'), in_hash[:project_use_test_preprocessor] ],
      [:project_test_preprocess_files_path,     File.join(project_build_tests_root, 'preprocess/files'),    in_hash[:project_use_test_preprocessor] ],

      [:project_test_dependencies_path,  File.join(project_build_tests_root, 'dependencies'), in_hash[:project_use_auxiliary_dependencies] ],
    ]

    out_hash[:project_build_paths] = []

    # fetch already set mock path
    out_hash[:project_build_paths] << in_hash[:cmock_mock_path] if (in_hash[:project_use_mocks])

    paths.each do |path|
      build_path_name          = path[0]
      build_path               = path[1]
      build_path_add_condition = path[2]
      
      # insert path into build paths if associated with true condition
      out_hash[:project_build_paths] << build_path if build_path_add_condition
      # set path symbol name and path for each entry in paths array
      out_hash[build_path_name] = build_path
    end

    return out_hash
  end


  def set_log_filepath(in_hash)
    log_name = File.basename(@project_config_manager.main_project_filepath).ext('')
    
    if (not @project_config_manager.user_project_filepath.empty?)
      log_name += "_#{File.basename(@project_config_manager.user_project_filepath).ext('')}"
    end
    
    if (not @project_config_manager.project_options_filepath.empty?)
      log_name += "_#{File.basename(@project_config_manager.project_options_filepath).ext('')}"
    end

    return {
      # tempted to make a helper method in file_path_utils? stop right there, pal. you'll introduce a cyclical dependency
      :project_log_filepath => File.join( in_hash[:project_log_path], log_name.ext('.log') )
      }
  end


  def set_rakefile_components(in_hash)
    out_hash = {
      :project_rakefile_component_files => 
        [File.join(CEEDLING_LIB, 'tasks_base.rake'),
         File.join(CEEDLING_LIB, 'tasks_filesystem.rake'),
         File.join(CEEDLING_LIB, 'tasks_tests.rake'),
         File.join(CEEDLING_LIB, 'rules_tests.rake')]}

    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_cmock.rake') if (in_hash[:project_use_mocks])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_preprocess.rake') if (in_hash[:project_use_test_preprocessor])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_tests_aux_dependencies.rake') if (in_hash[:project_use_auxiliary_dependencies])

    # order is important because of how rake processes and collapses the tasks & rules defined within
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_release_aux_dependencies.rake') if (in_hash[:project_release_build] and in_hash[:project_use_auxiliary_dependencies])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'rules_release.rake') if (in_hash[:project_release_build])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'tasks_release_aux_dependencies.rake') if (in_hash[:project_release_build] and in_hash[:project_use_auxiliary_dependencies])
    out_hash[:project_rakefile_component_files] << File.join(CEEDLING_LIB, 'tasks_release.rake') if (in_hash[:project_release_build])

    return out_hash
  end
  
  
  def set_release_target(in_hash)
    return {} if (not in_hash[:project_release_build])
    
    release_target_file = ((in_hash[:release_build_output].nil?) ? (DEFAULT_RELEASE_TARGET_NAME.ext(in_hash[:extension_executable])) : in_hash[:release_build_output])
    
    return {
      # tempted to make a helper method in file_path_utils? stop right there, pal. you'll introduce a cyclical dependency
      :project_release_build_target => File.join(in_hash[:project_release_artifacts_path], release_target_file)
      }
  end
  

  def collect_project_options(in_hash)
    return {
      :collection_project_options => @file_wrapper.directory_listing( File.join(in_hash[:project_options_path], '*.yml') )
      }
  end
  

  def expand_all_path_globs(in_hash)
    out_hash = {}
    path_keys = []
    
    in_hash.each_key do |key|
      next if (not key.to_s[0..4] == 'paths')
      path_keys << key
    end
    
    # sorted to provide assured order of traversal in test calls on mocks
    path_keys.sort.each do |key|
      out_hash["collection_#{key.to_s}".to_sym] = @file_system_utils.collect_paths( in_hash[key] )
    end
    
    return out_hash
  end


  def collect_source_and_include_paths(in_hash)
    return {
      :collection_paths_source_and_include => 
        in_hash[:collection_paths_source] + 
        in_hash[:collection_paths_include]
      }    
  end


  def collect_source_include_vendor_paths(in_hash)
    extra_paths = []
    extra_paths << FilePathUtils::form_ceedling_vendor_path('c_exception/lib') if (in_hash[:project_use_exceptions])

    return {
      :collection_paths_source_include_vendor => 
        in_hash[:collection_paths_source_and_include] + 
        extra_paths
      }    
  end


  def collect_test_support_source_include_paths(in_hash)
    return {
      :collection_paths_test_support_source_include => 
        in_hash[:collection_paths_test] +
        in_hash[:collection_paths_support] +
        in_hash[:collection_paths_source] + 
        in_hash[:collection_paths_include]
      }    
  end
  
  
  def collect_test_support_source_include_vendor_paths(in_hash)
    extra_paths = []
    extra_paths << FilePathUtils::form_ceedling_vendor_path('unity/src')
    extra_paths << FilePathUtils::form_ceedling_vendor_path('c_exception/lib') if (in_hash[:project_use_exceptions])
    extra_paths << FilePathUtils::form_ceedling_vendor_path('cmock/src')       if (in_hash[:project_use_mocks])
    extra_paths << in_hash[:cmock_mock_path]                                   if (in_hash[:project_use_mocks])

    return {
      :collection_paths_test_support_source_include_vendor => 
        in_hash[:collection_paths_test_support_source_include] +
        extra_paths
      }    
  end
  
  
  def collect_tests(in_hash)
    all_tests = @file_wrapper.instantiate_file_list

    in_hash[:collection_paths_test].each do |path|
      all_tests.include( File.join(path, "#{in_hash[:project_test_file_prefix]}*#{in_hash[:extension_source]}") )
    end

    return {:collection_all_tests => all_tests}
  end


  def collect_assembly(in_hash)
    all_assembly = @file_wrapper.instantiate_file_list

    return {:collection_all_assembly => all_assembly} if (not in_hash[:release_build_use_assembly])
    
    in_hash[:collection_paths_source].each do |path|
      all_assembly.include( File.join(path, "*#{in_hash[:extension_assembly]}") )
    end
    
    return {:collection_all_assembly => all_assembly}
  end


  def collect_source(in_hash)
    all_source = @file_wrapper.instantiate_file_list
    
    in_hash[:collection_paths_source].each do |path|
      all_source.include( File.join(path, "*#{in_hash[:extension_source]}") )
    end
    
    return {:collection_all_source => all_source}
  end


  def collect_headers(in_hash)
    all_headers = @file_wrapper.instantiate_file_list

    paths = 
      in_hash[:collection_paths_test] +
      in_hash[:collection_paths_support] +
      in_hash[:collection_paths_source] + 
      in_hash[:collection_paths_include]
    
    (paths).each do |path|
      all_headers.include( File.join(path, "*#{in_hash[:extension_header]}") )
    end
    
    return {:collection_all_headers => all_headers}
  end


  def collect_all_existing_compilation_input(in_hash)
    all_input = @file_wrapper.instantiate_file_list

    paths = 
      in_hash[:collection_paths_test] + 
      in_hash[:collection_paths_support] + 
      in_hash[:collection_paths_source] + 
      in_hash[:collection_paths_include] +
      [FilePathUtils::form_ceedling_vendor_path('unity/src')]
    
    paths << FilePathUtils::form_ceedling_vendor_path('c_exception/lib') if (in_hash[:project_use_exceptions])
    paths << FilePathUtils::form_ceedling_vendor_path('cmock/src') if (in_hash[:project_use_mocks])

    (paths).each do |path|
      all_input.include( File.join(path, "*#{in_hash[:extension_header]}") )
      all_input.include( File.join(path, "*#{in_hash[:extension_source]}") )
    end
    
    return {:collection_all_existing_compilation_input => all_input}    
  end


  def collect_test_and_vendor_defines(in_hash)
    test_defines = in_hash[:defines_test].clone

    test_defines.concat(in_hash[:unity_defines])
    test_defines.concat(in_hash[:cmock_defines])      if (in_hash[:project_use_mocks])
    test_defines.concat(in_hash[:cexception_defines]) if (in_hash[:project_use_exceptions])
    
    return {:collection_defines_test_and_vendor => test_defines}
  end

  def collect_release_and_vendor_defines(in_hash)
    release_defines = in_hash[:defines_release].clone
    
    release_defines.concat(in_hash[:cexception_defines]) if (in_hash[:project_use_exceptions])
    
    return {:collection_defines_release_and_vendor => release_defines}
  end

  # gather up all files that if changed should cause generated files on-disk to be regenerated
  # dependency on a change to our input configuration hash is handled elsewhere as it is dynamically formed during ceedling's execution
  def collect_code_generation_dependencies(hash)
    dependencies = []

    # Notes:
    #  - Compiled vendor dependencies like cmock.o, unity.o, cexception.o are handled below;
    #    here we're interested only in code generation dependencies
    #  - Symbols passed to compiler at command line can change Unity and CException behavior / configuration;
    #    we also handle those dependencies elsewhere in compilation dependencies
    
    ceedling_build_file = File.join(CEEDLING_RELEASE, 'build.info')
    cmock_build_file    = FilePathUtils::form_ceedling_vendor_path('cmock/release', 'build.info')

    # ceedling itself: if it changes we gotta regenerate files
    dependencies << ceedling_build_file
    
    # cmock: same as ceedling
    if (hash[:project_use_mocks])
      dependencies << cmock_build_file
      dependencies << hash[:cmock_unity_helper] if (hash[:cmock_unity_helper])
    end
    
    out_hash = {
      :collection_code_generation_dependencies => dependencies
    }
    
    return out_hash
  end


  def collect_test_fixture_link_objects(hash)
    # we don't include paths here because use of plugins or mixing compilers may require different build paths
    hash[:test_fixture_link_objects] << 'CException.c' if (hash[:project_use_exceptions])
    hash[:test_fixture_link_objects] << 'cmock.c'      if (hash[:project_use_mocks])
    
    # if we're using mocks & a unity helper is defined & that unity helper includes a source file component (not only a header of macros),
    # then link in the unity_helper object file too
    if ( hash[:project_use_mocks] and
         hash[:cmock_unity_helper] and 
         @file_wrapper.exist?(hash[:cmock_unity_helper].ext(hash[:extension_source])) )
      hash[:test_fixture_link_objects] << File.basename(hash[:cmock_unity_helper])
    end
    
    hash[:test_fixture_link_objects].map! { |link_object| link_object.ext(hash[:extension_object]) }
    hash[:test_fixture_link_objects].uniq!
  end
  
end
