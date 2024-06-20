# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Add sort-ability to symbol so we can order keys array in hash for test-ability
class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end


class ConfiguratorSetup

  constructor :configurator_builder, :configurator_validator, :configurator_plugins, :loginator, :file_wrapper


  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    # TODO: When identifying information is added to constructor, insert it into `inspect()` string
    return this.class.name
  end

  def build_project_config(ceedling_lib_path, flattened_config)
    ### flesh out config
    @configurator_builder.cleanup( flattened_config )
    @configurator_builder.set_exception_handling( flattened_config )

    ### add to hash values we build up from configuration & file system contents
    flattened_config.merge!( @configurator_builder.set_build_paths( flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_rakefile_components( ceedling_lib_path, flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_release_target( flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_build_thread_counts( flattened_config ) )

    return flattened_config
  end

  def build_directory_structure(flattened_config)
    flattened_config[:project_build_paths].each do |path|
      @file_wrapper.mkdir( path )
    end
  end

  def vendor_frameworks_and_support_files(ceedling_lib_path, flattened_config)
    # Copy Unity C files into build/vendor directory structure
    @file_wrapper.cp_r(
      # '/.' to cause cp_r to copy directory contents
      File.join( flattened_config[:unity_vendor_path], UNITY_LIB_PATH, '/.' ),
      flattened_config[:project_build_vendor_unity_path]
    )

    # Copy CMock C files into build/vendor directory structure
    @file_wrapper.cp_r(
      # '/.' to cause cp_r to copy directory contents
      File.join( flattened_config[:cmock_vendor_path], CMOCK_LIB_PATH, '/.' ),
      flattened_config[:project_build_vendor_cmock_path]
    ) if flattened_config[:project_use_mocks]

    # Copy CException C files into build/vendor directory structure
    @file_wrapper.cp_r(
      # '/.' to cause cp_r to copy directory contents
      File.join( flattened_config[:cexception_vendor_path], CEXCEPTION_LIB_PATH, '/.' ),
      flattened_config[:project_build_vendor_cexception_path]
    ) if flattened_config[:project_use_exceptions]

    # Copy backtrace debugging script into build/test directory structure
    @file_wrapper.cp_r(
      File.join( ceedling_lib_path, BACKTRACE_GDB_SCRIPT_FILE ),
      flattened_config[:project_build_tests_root]
    ) if flattened_config[:project_use_backtrace] == :gdb
  end

  def build_project_collections(flattened_config)
    # Iterate through all entries in paths section and expand any & all globs to actual paths
    flattened_config.merge!( @configurator_builder.expand_all_path_globs( flattened_config ) )

    flattened_config.merge!( @configurator_builder.collect_vendor_paths( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_source_and_include_paths( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_source_include_vendor_paths( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_test_support_source_include_paths( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_test_support_source_include_vendor_paths( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_tests( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_assembly( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_source( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_headers( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_release_build_input( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_existing_test_build_input( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_release_artifact_extra_link_objects( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_test_fixture_extra_link_objects( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_vendor_framework_sources( flattened_config ) )

    return flattened_config
  end


  def build_constants_and_accessors(config, context)
    @configurator_builder.build_global_constants(config)
    @configurator_builder.build_accessor_methods(config, context)
  end


  def validate_required_sections(config)
    validation = []
    validation << @configurator_validator.exists?(config, :project)
    validation << @configurator_validator.exists?(config, :paths)

    return false if (validation.include?(false))
    return true
  end


  def validate_required_section_values(config)
    validation = []
    validation << @configurator_validator.exists?(config, :project, :build_root)
    validation << @configurator_validator.exists?(config, :paths, :test)
    validation << @configurator_validator.exists?(config, :paths, :source)

    return false if (validation.include?(false))
    return true
  end


  def validate_paths(config)
    valid = true

    if config[:cmock][:unity_helper]
      config[:cmock][:unity_helper].each do |path|
        valid &= @configurator_validator.validate_filepath_simple( path, :cmock, :unity_helper ) 
      end
    end

    config[:plugins][:load_paths].each do |path|
      valid &= @configurator_validator.validate_filepath_simple( path, :plugins, :load_paths )
    end

    config[:paths].keys.sort.each do |key|
      valid &= @configurator_validator.validate_path_list(config, :paths, key)
      valid &= @configurator_validator.validate_paths_entries(config, key)
    end

    config[:files].keys.sort.each do |key|
      valid &= @configurator_validator.validate_path_list(config, :files, key)
      valid &= @configurator_validator.validate_files_entries(config, key)
    end

    return valid
  end

  def validate_tools(config)
    valid = true

    config[:tools].keys.sort.each do |tool|
      valid &= @configurator_validator.validate_tool( config:config, key:tool )
    end

    if config[:project][:use_backtrace] == :gdb
      valid &= @configurator_validator.validate_tool(
        config:config,
        key: :test_backtrace_gdb,
        respect_optional: false
      )
    end

    return valid
  end

  def validate_test_runner_generation(config, include_test_case, exclude_test_case)
    cmdline_args = config[:test_runner][:cmdline_args]

    # Test case filters in use
    test_case_filters = !include_test_case.empty? || !exclude_test_case.empty?

    # Test case filters are in use but test runner command line arguments are not enabled
    if (test_case_filters and !cmdline_args)
      msg = 'Test case filters cannot be used -- enable :test_runner ↳ :cmdline_args in your project configuration'
      @loginator.log( msg, Verbosity::ERRORS )
      return false
    end

    return true
  end

  def validate_backtrace(config)
    valid = true

    use_backtrace = config[:project][:use_backtrace]

    case use_backtrace
    when :none
      # Do nothing
    when :simple
      # Do nothing
    when :gdb
      # Do nothing
    else
      @loginator.log( ":project ↳ :use_backtrace is '#{use_backtrace}' but must be :none, :simple, or :gdb", Verbosity::ERRORS )
      valid = false
    end

    return valid
  end

  def validate_threads(config)
    valid = true

    compile_threads = config[:project][:compile_threads]
    test_threads = config[:project][:test_threads]

    case compile_threads
    when Integer
      if compile_threads < 1
        @loginator.log( ":project ↳ :compile_threads must be greater than 0", Verbosity::ERRORS )
        valid = false
      end
    when Symbol
      if compile_threads != :auto
        @loginator.log( ":project ↳ :compile_threads is neither an integer nor :auto", Verbosity::ERRORS ) 
        valid = false
      end
    else
      @loginator.log( ":project ↳ :compile_threads is neither an integer nor :auto", Verbosity::ERRORS ) 
      valid = false
    end

    case test_threads
    when Integer
      if test_threads < 1
        @loginator.log( ":project ↳ :test_threads must be greater than 0", Verbosity::ERRORS )
        valid = false
      end
    when Symbol
      if test_threads != :auto
        @loginator.log( ":project ↳ :test_threads is neither an integer nor :auto", Verbosity::ERRORS ) 
        valid = false
      end
    else
      @loginator.log( ":project ↳ :test_threads is neither an integer nor :auto", Verbosity::ERRORS ) 
      valid = false
    end

    return valid
  end

  def validate_plugins(config)
    missing_plugins =
      Set.new( config[:plugins][:enabled] ) -
      Set.new( @configurator_plugins.rake_plugins ) -
      Set.new( @configurator_plugins.programmatic_plugins.map {|p| p[:plugin]} )

    missing_plugins.each do |plugin|
      message = "Plugin '#{plugin}' not found in built-in or project Ruby load paths. Check load paths and plugin naming and path conventions."
      @loginator.log( message, Verbosity::ERRORS )
    end

    return ( (missing_plugins.size > 0) ? false : true )
  end

end
