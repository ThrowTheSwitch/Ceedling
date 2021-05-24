
class TestConfigCustomizator

  constructor :configurator,
              :streaminator,
              :file_wrapper,
              :cmock_builder

  def setup
    @standard_test_defines = {}
    @standard_test_paths = {}
    @standard_cmock = {}
  end


  def is_customized_test(test_name)
    def_test_key = "defines_#{test_name.downcase}".to_sym
    @configurator.project_config_hash.has_key?(def_test_key) || @configurator.defines_use_test_definition
  end

  def backup_test_config
    backup_standard_test_defines()
    backup_standard_test_paths()
  end

  def restore_test_config
    @streaminator.stdout_puts("Restored defines and build path to standard", Verbosity::NORMAL)
    set_standard_test_defines()
    set_standard_test_build_path()
  end

  def prepare_customized_test_config(test_name)
    @streaminator.stdout_puts("Updating test definitions and build path for #{test_name}", Verbosity::NORMAL)
    set_custom_test_defines(test_name)
    set_custom_test_build_path(test_name)
  end

  private

  def backup_standard_test_defines
    @standard_test_defines = Array.new(COLLECTION_DEFINES_TEST_AND_VENDOR)
  end

  def set_standard_test_defines
    COLLECTION_DEFINES_TEST_AND_VENDOR.replace(@standard_test_defines)
  end

  def set_custom_test_defines(test_name)
    def_test_key = "defines_#{test_name.downcase}".to_sym
    test_defs_cfg = Array.new(COLLECTION_DEFINES_TEST_AND_VENDOR)
    if @configurator.project_config_hash.has_key?(def_test_key)
      test_defs_cfg.replace(@configurator.project_config_hash[def_test_key])
      test_defs_cfg .concat(COLLECTION_DEFINES_VENDOR) if COLLECTION_DEFINES_VENDOR
    end
    if @configurator.defines_use_test_definition
      test_defs_cfg << test_name.strip.upcase.sub(/@.*$/, "")
    end
    COLLECTION_DEFINES_TEST_AND_VENDOR.replace(test_defs_cfg)
  end

  def backup_standard_test_paths
    @standard_test_paths[:project_test_build_output_path] = @configurator.project_test_build_output_path
    @standard_test_paths[:project_test_build_output_asm_path] = @configurator.project_test_build_output_asm_path
    @standard_test_paths[:project_test_build_output_c_path] = @configurator.project_test_build_output_c_path
    @standard_test_paths[:project_test_build_cache_path] = @configurator.project_test_build_cache_path
    @standard_test_paths[:project_test_dependencies_path] = @configurator.project_test_dependencies_path
    if @configurator.project_use_test_preprocessor
      @standard_test_paths[:project_test_preprocess_includes_path] = @configurator.project_test_preprocess_includes_path
      @standard_test_paths[:project_test_preprocess_files_path] = @configurator.project_test_preprocess_files_path
    end

    if @configurator.project_use_mocks
      @standard_test_paths[:cmock_mock_path] = @configurator.cmock_mock_path
      @standard_cmock[:cmock] = @cmock_builder.cmock
      @standard_cmock[:tool_search_paths] = Array.new(COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR)
    end
  end

  def set_standard_test_build_path
    @standard_test_paths.each do |config, path|
      @configurator.project_config_hash[config] = path
    end

    if @configurator.project_use_mocks
      @cmock_builder.cmock = @standard_cmock[:cmock]
      COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR.replace(@standard_cmock[:tool_search_paths])
    end
  end

  def set_custom_test_build_path(test_name)
    @standard_test_paths.each do |config, path|
      @configurator.project_config_hash[config] = File.join(path, test_name)
      @file_wrapper.mkdir(@configurator.project_config_hash[config])
    end 

    if @configurator.project_use_mocks
      cmock_config = @cmock_builder.cmock_config.clone
      cmock_config[:mock_path] = @configurator.project_config_hash[:cmock_mock_path]
      # fff replace @cmock_bulder.cmock from CMock during setup
      # we have to create new CMock of fff or other mock generator
      mock_generator = @cmock_builder.clone_mock_generator(cmock_config)
      @cmock_builder.cmock = mock_generator
      COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR.map! do |path|
        path == @standard_test_paths[:cmock_mock_path] ? @configurator.cmock_mock_path : path
      end
    end
  end

end
