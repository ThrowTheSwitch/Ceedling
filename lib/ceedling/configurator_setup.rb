# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'

# Add sort-ability to symbol so we can order keys array in hash for test-ability
class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end


class ConfiguratorSetup

  constructor :configurator_builder, :configurator_validator, :configurator_plugins, :loginator, :reportinator, :file_wrapper


  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    # TODO: When identifying information is added to constructor, insert it into `inspect()` string
    return this.class.name
  end

  def build_project_config(ceedling_lib_path, logging_path, flattened_config)
    # Housekeeping
    @configurator_builder.cleanup( flattened_config )

    # Add to hash values we build up from configuration & file system contents
    flattened_config.merge!( @configurator_builder.set_build_paths( flattened_config, logging_path ) )
    flattened_config.merge!( @configurator_builder.set_rakefile_components( ceedling_lib_path, flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_release_target( flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_build_thread_counts( flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_test_preprocessor_accessors( flattened_config ) )

    return flattened_config
  end

  def build_directory_structure(flattened_config)
    msg = "Build paths:"
    flattened_config[:project_build_paths].each do |path|
      msg += "\n - #{(path.nil? or path.empty?) ? '<empty>' : path}"
    end
    @loginator.log( msg, Verbosity::DEBUG )

    flattened_config[:project_build_paths].each do |path|
      if path.nil? or path.empty?
        raise CeedlingException.new( "An internal project build path subdirectory path is unexpectedly blank" )
      end

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

    # Ceedling ensures [:unity_helper_path] is an array
    config[:cmock][:unity_helper_path].each do |path|
      valid &= @configurator_validator.validate_filepath_simple( path, :cmock, :unity_helper_path ) 
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


  def validate_defines(_config)
    defines = _config[:defines]

    return true if defines.nil?

    # Ensure config[:defines] is a hash
    if defines.class != Hash
      msg = ":defines must contain key / value pairs, not #{defines.class.to_s.downcase} (see docs for examples)"
      @loginator.log( msg, Verbosity::ERRORS )
      return false
    end

    valid = true

    # Validate that each context contains only a list of symbols or a matcher hash for :test / :preprocess context
    #
    # :defines:
    #   :<context>:
    #    - FOO
    #    - BAR
    #
    # or
    #
    # :defines:
    #   :test:
    #     :<matcher>:
    #       - FOO
    #       - BAR
    #   :preprocess:
    #     :<matcher>:
    #       - FOO
    #       - BAR

    defines.each_pair do |context, config|
      walk = @reportinator.generate_config_walk( [:defines, context] )

      # Special handling for configuration setting, not a hash context container
      next if context == :use_test_definition

      # Matcher contexts (only contexts that support matcher hashes)
      if context == :test or context == :preprocess
        if config.class != Array and config.class != Hash
          msg = "#{walk} entry '#{config}' must be a list or matcher, not #{config.class.to_s.downcase} (see docs for examples)"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false
        end

      # All other (simple) contexts
      else
        # Handle the (probably) common case of trying to use matchers for any context other than :test or :preprocess
        if config.class == Hash
          msg = "#{walk} entry '#{config}' must be a list--matcher hashes only availalbe for :test & :preprocess contexts (see docs for details)"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false
        # Catchall for any oddball entries
        elsif config.class != Array
          msg = "#{walk} entry '#{config}' must be a list, not #{config.class.to_s.downcase} (see docs for examples)"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false
        end
      end
    end

    # Validate simple option of lists applied across an entire context of any name
    # :defines:
    #   :<context>: # :test, :release, etc.
    #    - FOO
    #    - BAR

    defines.each_pair do |context, config|
      # Only validate lists of compilation symbols in this block (look for matchers in next block)
      next if config.class != Array

      # Handle any YAML alias referencing causing a nested array
      config.flatten!()

      # Ensure each item in list is a string
      config.each do |symbol|
        if symbol.class != String
          walk = @reportinator.generate_config_walk( [:defines, context] )
          msg = "#{walk} list entry #{symbol} must be a string, not #{symbol.class.to_s.downcase} (see docs for examples)"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false
        end
      end
    end

    # Validate :test / :preprocess context matchers (hash) if they exist
    # :defines:
    #   :test:
    #     :<matcher>: # Can be wildcard, substring, or regular expression in a string or symbol
    #       - FOO
    #       - BAR
    #   :preprocess:
    #     :<matcher>: # Can be wildcard, substring, or regular expression in a string or symbol
    #       - FOO
    #       - BAR

    contexts = [:test, :preprocess]

    contexts.each do |context|
      matchers = defines[context]

      # Skip processing if context isn't present or is present but is not a matcher hash
      next if matchers.nil? or matchers.class != Hash

      # Inspect each test matcher
      matchers.each_pair do |matcher, symbols|

        walk = @reportinator.generate_config_walk( [:defines, context, matcher] )
    
        # Ensure container associated with matcher is a list
        if symbols.class != Array
          msg = "#{walk} entry '#{symbols}' is not a list of compilation symbols but a #{symbols.class.to_s.downcase}"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false

          # Skip further validation if matcher value is not a list of symbols
          next          
        end

        # Handle any YAML alias nesting in array
        symbols.flatten!()

        # Ensure matcher itself is a Ruby symbol or string
        if matcher.class != Symbol and matcher.class != String
          msg = "#{walk} matcher is not a string or symbol"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false

          # Skip further validation if matcher key is not a symbol
          next
        end

        walk = @reportinator.generate_config_walk( [:defines, context, matcher] )

        # Ensure each item in compilation symbols list for matcher is a string
        symbols.each do |symbol|
          if symbol.class != String
            msg = "#{walk} entry '#{symbol}' is not a string"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          end
        end

        begin
          @configurator_validator.validate_matcher( matcher.to_s.strip() )
        rescue Exception => ex
          msg = "Matcher #{walk} contains #{ex.message}"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false
        end

      end
    end

    return valid
  end


  def validate_flags(_config)
    flags = _config[:flags]

    return true if flags.nil?

    # Ensure config[:flags] is a hash
    if flags.class != Hash
      msg = ":flags must contain key / value pairs, not #{flags.class.to_s.downcase} (see docs for examples)"
      @loginator.log( msg, Verbosity::ERRORS )
      # Immediately bail out
      return false
    end

    valid = true

    # Validate that each context has an operation hash
    # :flags
    #   :<context>:     # :test, :release, etc.
    #     :<operation>: # :compile, :link, etc.
    #       ...

    flags.each_pair do |context, operations|
      walk = @reportinator.generate_config_walk( [:flags, context] )

      if operations.nil?
        msg = "#{walk} operations key / value pairs are missing"
        @loginator.log( msg, Verbosity::ERRORS )

        valid = false
        next
      end

      if operations.class != Hash
        example = @reportinator.generate_config_walk( [:flags, context, :compile] )
        msg = "#{walk} context must contain :<operation> key / value pairs, not #{operations.class.to_s.downcase} '#{operations}' (ex. #{example})"
        @loginator.log( msg, Verbosity::ERRORS )

        # Immediately bail out
        return false
      end
    end

    if !!flags[:release] and !!flags[:release][:preprocess]
      walk = @reportinator.generate_config_walk( [:flags, :release, :preprocess] )
      msg = "Preprocessing configured at #{walk} is only supported in the :test context"
      @loginator.log( msg, Verbosity::ERRORS, LogLabels::WARNING )      
    end

    # Validate that each <:context> ↳ <:operation> contains only a list of flags or that :test ↳ <:operation> optionally contains a matcher hash
    #
    # :flags:
    #   :<context>:      # :test or :release
    #     :<operation>:  # :compile, :link, or :assemble (plus :preprocess for :test context)
    #      - --flag
    #
    # or
    #
    # :flags:
    #   :test:
    #     :<operation>:
    #       :<matcher>:
    #         - --flag

    flags.each_pair do |context, operations|
      operations.each_pair do |operation, config|
        walk = @reportinator.generate_config_walk( [:flags, context, operation] )

        if config.nil?
          msg = "#{walk} is missing a list or matcher hash"
          @loginator.log( msg, Verbosity::ERRORS )

          valid = false
          next
        end

        # :test context operations with lists or matchers (hashes)
        if context == :test
          if config.class != Array and config.class != Hash
            msg = "#{walk} entry '#{config}' must be a list or matcher hash, not #{config.class.to_s.downcase} (see docs for examples)"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          end

        # Other (simple) contexts
        else
          # Handle the (probably) common case of trying to use matchers for operations in any context other than :test
          if config.class == Hash
            msg = "#{walk} entry '#{config}' must be a list--matcher hashes only availalbe for :test context (see docs for details)"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          # Catchall for any oddball entries
          elsif config.class != Array
            msg = "#{walk} entry '#{config}' must be a list, not #{config.class.to_s.downcase} (see docs for examples)"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          end
        end
      end
    end

    # Validate simple option of lists of flags (strings) for <:context> ↳ <:operation>
    # :flags
    #   :<context>:
    #     :<operation>:
    #       - --flag

    flags.each_pair do |context, operations|
      operations.each_pair do |operation, flags|

        # Only validate lists of flags in this block (look for matchers in next block)
        next if flags.class != Array

        # Handle any YAML alias referencing causing a nested array
        flags.flatten!()

        # Ensure each item in list is a string
        flags.each do |flag|
          if flag.class != String
            walk = @reportinator.generate_config_walk( [:flags, context, operation] )
            msg = "#{walk} simple list entry '#{flag}' must be a string, not #{flag.class.to_s.downcase} (see docs for examples)"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          end
        end
      end
    end

    # Validate :test ↳ <:operation> matchers (hash) if they exist
    # :flags:
    #   :test:
    #     :<operation>: # :preprocess, :compile, :assemble, :link
    #       :<matcher>: # Can be wildcard, substring, or regular expression as a Ruby string or symbol
    #         - FOO
    #         - BAR

    # If there's no test context, we're done    
    test_context = flags[:test]
    return valid if test_context.nil?

    matchers_present = false
    test_context.each_pair do |operation, matchers|
      if matchers.class == Hash
        matchers_present = true
        break
      end
    end

    # If there's no matchers for :test ↳ <:operation>, we're done
    return valid if !matchers_present

    # Inspect each :test ↳ <:operation> matcher
    test_context.each_pair do |operation, matchers|
      # Only validate matchers (skip simple lists of flags)
      next if matchers.class != Hash

      matchers.each_pair do |matcher, flags|
        # Ensure matcher itself is a Ruby symbol or string
        if matcher.class != Symbol and matcher.class != String
          walk = @reportinator.generate_config_walk( [:flags, :test, operation] )
          msg = "#{walk} entry '#{matcher}' is not a string or symbol"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false

          # Skip further validation if matcher key is not a string or symbol
          next
        end

        walk = @reportinator.generate_config_walk( [:flags, :test, operation, matcher] )

        # Ensure container associated with matcher is a list
        if flags.class != Array
          msg = "#{walk} entry '#{flags}' is not a list of command line flags but a #{flags.class.to_s.downcase}"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false

          # Skip further validation if matcher value is not a list of flags
          next          
        end

        # Handle any YAML alias nesting in array
        flags.flatten!()
        
        # Ensure each item in flags list for matcher is a string
        flags.each do |flag|
          if flag.class != String
            msg = "#{walk} entry '#{flag}' is not a string"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          end
        end

        begin
          @configurator_validator.validate_matcher( matcher.to_s.strip() )
        rescue Exception => ex
          msg = "Matcher #{walk} contains #{ex.message}"
          @loginator.log( msg, Verbosity::ERRORS )
          valid = false
        end

      end
    end

    return valid
  end


  def validate_test_preprocessor(config)
    valid = true

    options = [:none, :all, :tests, :mocks]

    use_test_preprocessor = config[:project][:use_test_preprocessor]

    if !options.include?( use_test_preprocessor )
      walk = @reportinator.generate_config_walk( [:project, :use_test_preprocessor] )
      msg = "#{walk} is :'#{use_test_preprocessor}' but must be one of #{options.map{|o| ':' + o.to_s()}.join(', ')}"
      @loginator.log( msg, Verbosity::ERRORS )
      valid = false
    end

    return valid
  end


  def validate_environment_vars(config)
    environment = config[:environment]

    return true if environment.nil?

    # Ensure config[:environment] is an array (of simple hashes--validated below)
    if environment.class != Array
      msg = ":environment must contain a list of key / value pairs, not #{environment.class.to_s.downcase} (see docs for examples)"
      @loginator.log( msg, Verbosity::ERRORS )
      return false
    end

    valid = true
    keys = []

    # Ensure a hash for each entry
    environment.each do |entry|
      if entry.class != Hash
        msg = ":environment list entry #{entry} is not a key / value pair (ex. :var: value)"
        @loginator.log( msg, Verbosity::ERRORS )
        valid = false
      end
    end

    # Only end processing if an entry wasn't a hash
    return valid if !valid

    # Validate each hash entry
    environment.each do |entry|
      key_length = entry.keys.length()

      # Ensure entry is a hash with just a single key / value pair
      if key_length != 1
        msg = ":environment entry #{entry} does not specify exactly one key (see docs for examples)"
        @loginator.log( msg, Verbosity::ERRORS )
        valid = false
      end

      key   = entry.keys[0] # Get first (should be only) environment variable entry
      value = entry[key]    # Get associated value

      # Remember key for later duplication check
      keys << key.to_s.downcase

      # Ensure entry key is a symbol or string
      if key.class != Symbol and key.class != String
        msg = ":environment entry '#{key}' must be a symbol or string (:#{key})"
        @loginator.log( msg, Verbosity::ERRORS )
        valid = false

        # Skip validation of value if key is not a symbol or string
        next
      end

      # Ensure entry value is a string or list
      if not (value.class == String or value.class == Array)
        msg = ":environment entry #{key} is associated with #{value.class.to_s.downcase}, not a string or list (see docs for details)"
        @loginator.log( msg, Verbosity::ERRORS )
        valid = false
      end

      # If path is a list, ensure it's all strings
      if value.class == Array
        value.each do |item|
          if item.class != String
            msg = ":environment entry #{key} contains a list element '#{item}' (#{item.class.to_s.downcase}) that is not a string"
            @loginator.log( msg, Verbosity::ERRORS )
            valid = false
          end
        end
      end
    end

    # Find any duplicate keys
    dups = keys.uniq.select { |k| keys.count( k ) > 1 }
    
    if !dups.empty?
      msg = "Duplicate :environment entr#{dups.length() == 1 ? 'y' : 'ies'} #{dups.map{|d| ':' + d.to_s}.join( ', ' )} found"
      @loginator.log( msg, Verbosity::ERRORS )
      valid = false
    end
    
    return valid
  end


  def validate_backtrace(config)
    valid = true

    options = [:none, :simple, :gdb]

    use_backtrace = config[:project][:use_backtrace]

    if !options.include?( use_backtrace )
      walk = @reportinator.generate_config_walk( [:project, :use_backtrace] )

      msg = "#{walk} is :'#{use_backtrace}' but must be one of #{options.map{|o| ':' + o.to_s()}.join(', ')}"
      @loginator.log( msg, Verbosity::ERRORS )
      valid = false
    end

    return valid
  end

  def validate_threads(config)
    valid = true

    compile_threads = config[:project][:compile_threads]
    test_threads = config[:project][:test_threads]

    walk = @reportinator.generate_config_walk( [:project, :compile_threads] )

    case compile_threads
    when Integer
      if compile_threads < 1
        @loginator.log( "#{walk} must be greater than 0", Verbosity::ERRORS )
        valid = false
      end
    when Symbol
      if compile_threads != :auto
        @loginator.log( "#{walk} is neither an integer nor :auto", Verbosity::ERRORS ) 
        valid = false
      end
    else
      @loginator.log( "#{walk} is neither an integer nor :auto", Verbosity::ERRORS ) 
      valid = false
    end

    walk = @reportinator.generate_config_walk( [:project, :test_threads] )

    case test_threads
    when Integer
      if test_threads < 1
        @loginator.log( "#{walk} must be greater than 0", Verbosity::ERRORS )
        valid = false
      end
    when Symbol
      if test_threads != :auto
        @loginator.log( "#{walk} is neither an integer nor :auto", Verbosity::ERRORS ) 
        valid = false
      end
    else
      @loginator.log( "#{walk} is neither an integer nor :auto", Verbosity::ERRORS ) 
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
