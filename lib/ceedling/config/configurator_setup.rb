# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'


class ConfiguratorSetup

  constructor :configurator_builder, :configurator_validator, :loginator, :reportinator, :file_wrapper,
              :system_wrapper, :tool_executor

  # Path collections, in order, since each builds on those before it
  PATH_COLLECTIONS = [
    :expand_all_path_globs,
    :collect_vendor_paths,
    :collect_source_and_include_paths,
    :collect_source_include_vendor_paths,
    :collect_test_support_source_include_paths,
    :collect_test_support_source_include_vendor_paths
  ].freeze

  # File collections gathered after tests, assembly, and sources
  FILE_COLLECTIONS = [
    :collect_headers,
    :collect_release_build_input,
    :collect_existing_test_build_input,
    :collect_release_artifact_extra_link_objects,
    :collect_test_fixture_extra_link_objects,
    :collect_vendor_framework_sources
  ].freeze


  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    return self.class.name
  end

  def build_project_config(ceedling_lib_path, logging_path, flattened_config)
    # Add to hash values we build up from configuration & file system contents
    flattened_config.merge!( @configurator_builder.set_build_paths( flattened_config, logging_path ) )
    flattened_config.merge!( @configurator_builder.set_rakefile_components( ceedling_lib_path, flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_release_target( flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_build_thread_counts( flattened_config ) )
    flattened_config.merge!( @configurator_builder.set_test_preprocessor_accessors( flattened_config ) )

    return flattened_config
  end

  def build_directory_structure(flattened_config)
    _paths = flattened_config[:project_build_paths].map { |p| (p.nil? || p.empty?) ? '<empty>' : p }
    @loginator.log_list( _paths, "Build paths:", Verbosity::DEBUG )

    flattened_config[:project_build_paths].each do |path|
      if path.nil? or path.empty?
        raise CeedlingException.new( "An internal project build path subdirectory path is unexpectedly blank" )
      end

      @file_wrapper.mkdir( path )
    end
  end

  # A vendor destination must be a directory, and the marker file inside it (unity.c,
  # cmock.c, CException.c) a plain file. An interrupted run, or a second Ceedling run racing
  # this one, can leave either as the wrong type, and the copy would then fail on every
  # later build. The whole destination is cleared, so the copy recreates it.
  def heal_vendor_path(path, marker_file)
    return unless corrupted_vendor_path?( path, marker_file )

    @loginator.log( "Removing corrupted vendor path (unexpected file/directory type): #{path}", Verbosity::COMPLAIN, LogLabels::NOTICE )
    @file_wrapper.rm_rf( path )
  end

  # Copies the frameworks a build uses into build/vendor, and the support files its
  # features need. Copies always, every run. An errant edit beneath build/vendor/, by hand,
  # an IDE, or an automated agent, is overwritten from the canonical source by the next build.
  def vendor_frameworks_and_support_files(ceedling_lib_path, flattened_config)
    vendored_frameworks( flattened_config ).each do |source, destination, marker_file|
      heal_vendor_path( destination, marker_file )
      # '/.' to cause cp_r to copy directory contents
      @file_wrapper.cp_r_with_retry( File.join( source, '/.' ), destination )
    end

    copy_backtrace_script( ceedling_lib_path, flattened_config ) if flattened_config[:project_use_backtrace] == :gdb

    # Copy supporting partials code into build/vendor directory structure
    @file_wrapper.cp_r(
      File.join( ceedling_lib_path, CEEDLING_HEADER_FILEPATH ),
      flattened_config[:project_build_vendor_ceedling_path]
    ) if flattened_config[:project_use_partials]
  end

  # Tests are collected after path collections, both to merge and to filter out of sources
  def build_project_collections(flattened_config)
    PATH_COLLECTIONS.each { |collection| flattened_config.merge!( @configurator_builder.public_send( collection, flattened_config ) ) }

    tests_collection, tests_list = @configurator_builder.collect_tests( flattened_config )
    flattened_config.merge!( tests_collection )
    flattened_config.merge!( @configurator_builder.collect_assembly( flattened_config ) )
    flattened_config.merge!( @configurator_builder.collect_source( flattened_config, tests_list ) )

    FILE_COLLECTIONS.each { |collection| flattened_config.merge!( @configurator_builder.public_send( collection, flattened_config ) ) }

    return flattened_config
  end


  def build_constants_and_accessors(config, target)
    @configurator_builder.build_global_constants(config)
    @configurator_builder.build_accessor_methods(config, target)
  end


  def validate_required_sections(config)
    return [:project, :paths].map { |section| @configurator_validator.exists?( config, section ) }.all?
  end


  def validate_required_section_values(config)
    required = [ [:project, :build_root], [:paths, :test], [:paths, :source] ]
    return required.map { |keys| @configurator_validator.exists?( config, *keys ) }.all?
  end


  # Every check runs, so every problem is reported
  def validate_paths(config)
    valid  = validate_simple_paths( config[:cmock][:unity_helper_path], :cmock, :unity_helper_path )
    valid &= validate_simple_paths( config[:plugins][:load_paths], :plugins, :load_paths )
    valid &= validate_path_section( config, :paths, :validate_paths_entries )
    valid &= validate_path_section( config, :files, :validate_files_entries )

    return valid
  end

  def validate_tools(config)
    valid = true

    config[:tools].keys.sort.each do |tool|
      valid &= @configurator_validator.validate_tool( config:config, key:tool )
    end

    validate_gdb_attach_capability( config )

    return valid
  end

  # A gdb that answers `--version` may still be unable to attach to a process. macOS often
  # revokes a Homebrew gdb's debugger entitlement, after a Homebrew upgrade, a macOS update,
  # or a Gatekeeper or taskgated cache reset. A project using `:use_backtrace: :gdb` on such
  # a machine falls back to `:simple` backtraces with a warning, rather than failing validation.
  def validate_gdb_attach_capability(config)
    return unless config[:project][:use_backtrace] == :gdb
    return unless @system_wrapper.macos?

    # The probe runs with :boom false, so its :exit_code is not the real exit code.
    # Success comes from the process status.
    result = probe_gdb_attach()
    return if result[:status]&.success?

    config[:project][:use_backtrace] = :simple

    walk = @reportinator.generate_config_walk( [:project, :use_backtrace] )
    msg = "#{walk} is ':gdb' but #{gdb_attach_failure( result )}. Falling back to ':simple' for this run."
    @loginator.log( msg, Verbosity::ERRORS, LogLabels::WARNING )
  end

  # Launches a short-lived process, attaches gdb to it, and detaches at once. A clean
  # attach proves gdb works here, which `--version` cannot. One shell command keeps the
  # success path fast.
  def probe_gdb_attach()
    command = {
      name: 'gdb_attach_probe',
      line: %q{sh -c 'sleep 5 & pid=$!; gdb -q --batch --pid "$pid" --eval-command detach 2>&1; rc=$?; kill "$pid" 2>/dev/null; exit $rc'},
      options: { boom: false }
    }

    return @tool_executor.exec( command )
  end


  # Each :defines context holds a list of symbols. :test and :preprocess may instead hold a
  # matcher hash of test filename matchers, each naming a list of symbols.
  #
  # :defines:
  #   :<context>:
  #     - FOO
  #   :test:
  #     :<matcher>:
  #       - FOO
  def validate_defines(config)
    defines = config[:defines]

    return true if defines.nil?
    return log_invalid( ":defines must contain key / value pairs, not #{defines.class.to_s.downcase} (see docs for examples)" ) unless defines.is_a?( Hash )

    matcher_contexts = matcher_contexts( config, [:test, :preprocess] )

    # :use_test_definition is a setting, not a context
    return defines.reject { |context, _| context == :use_test_definition }.map do |context, entries|
      validate_entries( [:defines, context], entries, matcher_contexts, 'compilation symbols' )
    end.all?
  end


  # Each :flags context holds operations, each a list of flags. :test operations may instead
  # hold a matcher hash of test filename matchers, each naming a list of flags.
  #
  # :flags:
  #   :<context>:
  #     :<operation>:
  #       - --flag
  #   :test:
  #     :<operation>:
  #       :<matcher>:
  #         - --flag
  def validate_flags(config)
    flags = config[:flags]

    return true if flags.nil?
    return log_invalid( ":flags must contain key / value pairs, not #{flags.class.to_s.downcase} (see docs for examples)" ) unless flags.is_a?( Hash )

    warn_of_release_preprocessing( flags )

    matcher_contexts = matcher_contexts( config, [:test] )

    return flags.map { |context, operations| validate_flags_context( context, operations, matcher_contexts ) }.all?
  end


  def validate_test_preprocessor(config)
    return validate_option( config, :use_test_preprocessor, [:none, :all, :tests, :mocks] )
  end


  # :environment is a list of single-pair hashes, each a variable name and a string or list of strings
  def validate_environment_vars(config)
    environment = config[:environment]

    return true if environment.nil?
    return log_invalid( ":environment must contain a list of key / value pairs, not #{environment.class.to_s.downcase} (see docs for examples)" ) unless environment.is_a?( Array )

    # Entries are inspected further only once every one is a key / value pair
    return false unless validate_environment_pairs( environment )

    valid = environment.map { |entry| validate_environment_entry( entry ) }.all?
    return valid & validate_unique_environment_names( environment )
  end


  def validate_backtrace(config)
    return validate_option( config, :use_backtrace, [:none, :simple, :gdb] )
  end

  def validate_threads(config)
    return [:compile_threads, :test_threads].map { |key| validate_thread_count( config, key ) }.all?
  end

  # `:max_extraction_length` multiplies 1000 characters, so `5000` reads more clearly than
  # `5000000`. The minimum keeps that ceiling well above any ordinary C declaration or
  # signature, and catches `1000` written to mean 1000 characters.
  def validate_partials(config)
    max_extraction_length = config[:partials][:max_extraction_length]
    walk = @reportinator.generate_config_walk( [:partials, :max_extraction_length] )

    return log_invalid( "#{walk} is not an integer" ) unless max_extraction_length.is_a?( Integer )
    return log_invalid( "#{walk} must be at least 10 (10,000 characters)" ) if max_extraction_length < 10
    return true
  end

  # Discovery records a path beneath :plugins for each enabled plugin it found, whatever
  # kind of plugin it is
  def validate_plugins(config)
    missing_plugins = config[:plugins][:enabled].reject { |plugin| config[:plugins].key?( :"#{plugin}_path" ) }

    missing_plugins.each do |plugin|
      message = "Plugin '#{plugin}' not found in built-in or project Ruby load paths. Check load paths and plugin naming and path conventions."
      @loginator.log( message, Verbosity::ERRORS )
    end

    return missing_plugins.empty?
  end

  ### Private ###

  private

  def corrupted_vendor_path?(path, marker_file)
    marker = File.join( path, marker_file )

    return ( @file_wrapper.exist?( path ) && !@file_wrapper.directory?( path ) ) ||
           ( @file_wrapper.exist?( marker ) && @file_wrapper.directory?( marker ) )
  end

  # Each framework a build uses, as [vendored source, build destination, marker file]
  def vendored_frameworks(config)
    frameworks = [ [File.join( config[:unity_vendor_path], UNITY_LIB_PATH ), config[:project_build_vendor_unity_path], UNITY_C_FILE] ]

    if config[:project_use_mocks]
      frameworks << [File.join( config[:cmock_vendor_path], CMOCK_LIB_PATH ), config[:project_build_vendor_cmock_path], CMOCK_C_FILE]
    end

    if config[:project_use_exceptions]
      frameworks << [File.join( config[:cexception_vendor_path], CEXCEPTION_LIB_PATH ), config[:project_build_vendor_cexception_path], CEXCEPTION_C_FILE]
    end

    return frameworks
  end

  # The destination may not exist yet on a fresh build, since Rake creates directories
  # after configuration
  def copy_backtrace_script(ceedling_lib_path, flattened_config)
    @file_wrapper.mkdir( flattened_config[:project_build_tests_root] )
    @file_wrapper.cp_r( File.join( ceedling_lib_path, BACKTRACE_GDB_SCRIPT_FILE ), flattened_config[:project_build_tests_root] )
  end

  def validate_simple_paths(paths, *keys)
    return paths.map { |path| @configurator_validator.validate_filepath_simple( path, *keys ) }.all?
  end

  # Each entry of :paths or :files must exist and yield what its section expects
  def validate_path_section(config, section, entries_validation)
    return config[section].keys.sort.map do |key|
      @configurator_validator.validate_path_list( config, section, key ) & @configurator_validator.public_send( entries_validation, config, key )
    end.all?
  end

  def gdb_attach_failure(result)
    reason = "`gdb` could not attach to a probe process"
    return reason + " -- this is a macOS `gdb` codesigning / trust problem" if result[:output].to_s.match?( /Unable to find Mach task port/ )
    return reason
  end

  # Build contexts that plugins declare peers of :test also support matchers
  def matcher_contexts(config, contexts)
    return contexts + Array( config.dig( :plugins, :test_build_contexts ) ).map( &:to_sym )
  end

  # A context's entries are a list of strings, or, in a context supporting matchers, a
  # matcher hash. The context is the second key walked. `noun` names what the strings are.
  def validate_entries(walk_keys, entries, matcher_contexts, noun)
    return false unless validate_entries_form( walk_keys, entries, matcher_contexts )
    return validate_string_list( walk_keys, entries ) if entries.is_a?( Array )
    return validate_matchers( walk_keys, entries, noun )
  end

  def validate_entries_form(walk_keys, entries, matcher_contexts)
    walk     = @reportinator.generate_config_walk( walk_keys )
    kind     = entries.class.to_s.downcase
    matchers = matcher_contexts.include?( walk_keys[1] )

    return true if entries.is_a?( Array ) or (matchers and entries.is_a?( Hash ))
    return log_invalid( "#{walk} entry '#{entries}' must be a list or matcher hash, not #{kind} (see docs for examples)" ) if matchers
    return log_invalid( "#{walk} entry '#{entries}' must be a list, not #{kind} (see docs for examples)" ) unless entries.is_a?( Hash )

    contexts = matcher_contexts.map { |context| ":#{context}" }.join( ' & ' )
    return log_invalid( "#{walk} entry '#{entries}' must be a list; matcher hashes are only available for #{contexts} (see docs for details)" )
  end

  # A YAML alias can nest a list, so the list is flattened in place first
  def validate_string_list(walk_keys, list)
    walk = @reportinator.generate_config_walk( walk_keys )

    list.flatten!
    non_strings = list.reject { |item| item.is_a?( String ) }

    non_strings.each { |item| log_error( "#{walk} list entry '#{item}' must be a string, not #{item.class.to_s.downcase} (see docs for examples)" ) }
    return non_strings.empty?
  end

  # Each matcher must be a well-formed string or symbol naming a list of strings
  def validate_matchers(walk_keys, matchers, noun)
    return matchers.map { |matcher, list| validate_matcher_entry( walk_keys, matcher, list, noun ) }.all?
  end

  def validate_matcher_entry(walk_keys, matcher, list, noun)
    unless matcher.is_a?( Symbol ) or matcher.is_a?( String )
      return log_invalid( "#{@reportinator.generate_config_walk( walk_keys )} matcher '#{matcher}' is not a string or symbol" )
    end

    walk = @reportinator.generate_config_walk( walk_keys + [matcher] )
    return log_invalid( "#{walk} entry '#{list}' is not a list of #{noun} but a #{list.class.to_s.downcase}" ) unless list.is_a?( Array )

    return valid_matcher?( matcher, walk ) & validate_matcher_list( walk, list )
  end

  # A YAML alias can nest a list, so the list is flattened in place first
  def validate_matcher_list(walk, list)
    list.flatten!
    non_strings = list.reject { |item| item.is_a?( String ) }
    non_strings.each { |item| log_error( "#{walk} entry '#{item}' is not a string" ) }

    return non_strings.empty?
  end

  def valid_matcher?(matcher, walk)
    @configurator_validator.validate_matcher( matcher.to_s.strip )
    return true
  rescue StandardError => ex
    return log_invalid( "Matcher #{walk} contains #{ex.message}" )
  end

  def validate_flags_context(context, operations, matcher_contexts)
    walk = @reportinator.generate_config_walk( [:flags, context] )

    return log_invalid( "#{walk} operations key / value pairs are missing" ) if operations.nil?

    unless operations.is_a?( Hash )
      example = @reportinator.generate_config_walk( [:flags, context, :compile] )
      return log_invalid( "#{walk} context must contain :<operation> key / value pairs, not #{operations.class.to_s.downcase} '#{operations}' (ex. #{example})" )
    end

    return operations.map { |operation, entries| validate_flags_operation( [:flags, context, operation], entries, matcher_contexts ) }.all?
  end

  def validate_flags_operation(walk_keys, entries, matcher_contexts)
    return log_invalid( "#{@reportinator.generate_config_walk( walk_keys )} is missing a list or matcher hash" ) if entries.nil?
    return validate_entries( walk_keys, entries, matcher_contexts, 'command line flags' )
  end

  def warn_of_release_preprocessing(flags)
    return unless flags[:release].is_a?( Hash ) and flags[:release][:preprocess]

    walk = @reportinator.generate_config_walk( [:flags, :release, :preprocess] )
    @loginator.log( "Preprocessing configured at #{walk} is only supported in the :test context", Verbosity::ERRORS, LogLabels::WARNING )
  end

  def validate_option(config, key, options)
    value = config[:project][key]
    return true if options.include?( value )

    walk = @reportinator.generate_config_walk( [:project, key] )
    return log_invalid( "#{walk} is ':#{value}' but must be one of {#{options.map { |option| ":#{option}" }.join( ', ' )}}" )
  end

  def validate_thread_count(config, key)
    threads = config[:project][key]
    walk = @reportinator.generate_config_walk( [:project, key] )

    return true if threads == :auto or (threads.is_a?( Integer ) and threads >= 1)
    return log_invalid( "#{walk} must be greater than 0" ) if threads.is_a?( Integer )
    return log_invalid( "#{walk} is neither an integer nor :auto" )
  end

  def validate_environment_pairs(environment)
    non_pairs = environment.reject { |entry| entry.is_a?( Hash ) }
    non_pairs.each { |entry| log_error( ":environment list entry #{entry} is not a key / value pair (ex. :var: value)" ) }

    return non_pairs.empty?
  end

  def validate_environment_entry(entry)
    valid = (entry.keys.length == 1) || log_invalid( ":environment entry #{entry} does not specify exactly one key (see docs for examples)" )

    name, value = entry.first
    return log_invalid( ":environment entry '#{name}' must be a symbol or string (:#{name})" ) unless name.is_a?( Symbol ) or name.is_a?( String )

    return valid & validate_environment_value( name, value )
  end

  def validate_environment_value(name, value)
    case value
    when String then return true
    when Array
      non_strings = value.reject { |item| item.is_a?( String ) }
      non_strings.each { |item| log_error( ":environment entry #{name} contains a list element '#{item}' (#{item.class.to_s.downcase}) that is not a string" ) }
      return non_strings.empty?
    end

    return log_invalid( ":environment entry #{name} is associated with #{value.class.to_s.downcase}, not a string or list (see docs for details)" )
  end

  # Environment variable names are case-insensitive on some platforms
  def validate_unique_environment_names(environment)
    names = environment.map { |entry| entry.keys[0].to_s.downcase }
    dups  = names.select { |name| names.count( name ) > 1 }.uniq
    return true if dups.empty?

    return log_invalid( "Duplicate :environment entr#{dups.length == 1 ? 'y' : 'ies'} #{dups.map { |dup| ':' + dup }.join( ', ' )} found" )
  end

  def log_error(message)
    @loginator.log( message, Verbosity::ERRORS )
  end

  # Logs an error and answers false, for a validation to return
  def log_invalid(message)
    log_error( message )
    return false
  end

end
