# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants' # From Ceedling application

class MixinResolvinator

  constructor :file_wrapper, :path_validator, :loginator, :ruby_expandinator

  # Pick apart a :mixins projcet configuration section and return components
  # Layout mirrors :plugins section
  def extract_mixins(config:)
    # Get mixins config hash
    _mixins = config[:mixins]

    # If no :mixins section, return:
    #  - Empty enabled list
    #  - Empty load paths
    return [], [] if _mixins.nil?

    # Build list of load paths
    # Configured load paths are higher in search path ordering
    load_paths = _mixins[:load_paths] || []

    # Get list of mixins
    enabled = _mixins[:enabled] || []
    enabled = enabled.clone # Ensure it's a copy of configuration section

    # Handle any inline Ruby string expansion, then standardize Windows backslashes --
    # cmdline and env var mixin paths already go through standardize_paths elsewhere,
    # so config :mixins section paths need the same treatment for consistency.
    load_paths.each do |load_path|
      load_path.replace( @ruby_expandinator.expand( load_path, source: ":mixins ↳ :load_paths" ) )
      load_path.replace( @path_validator.standardize_paths( load_path ).first )
    end

    enabled.each do |mixin|
      mixin.replace( @ruby_expandinator.expand( mixin, source: ":mixins ↳ :enabled" ) )
      mixin.replace( @path_validator.standardize_paths( mixin ).first )
    end

    # Remove the :mixins section of the configuration
    config.delete( :mixins )

    return enabled, load_paths
  end


  # Validate :load_paths from :mixins section in project configuration
  def validate_mixin_load_paths(load_paths)
    validated = @path_validator.validate(
      paths: load_paths,
      source: 'Config :mixins ↳ :load_paths =>',
      type: :directory
    )

    if !validated
      raise 'Project configuration file section :mixins failed validation'
    end
  end


  # Validate mixins list
  def validate_mixins(mixins:, load_paths:, source:, yaml_extension:)
    validated = true

    mixins.each do |mixin|
      # Validate mixin filepaths
      if @path_validator.filepath?( mixin )
        if !@file_wrapper.exist?( mixin )
          @loginator.log( "Cannot find mixin at #{mixin}", Verbosity::ERRORS )
          validated = false
        end

      # Otherwise, validate that mixin name can be found in load paths
      else
        found = false
        load_paths.each do |path|
          if @file_wrapper.exist?( File.join( path, mixin + yaml_extension ) )
            found = true
            break
          end
        end

        if !found
          msg = "#{source} '#{mixin}' cannot be found in mixin load paths as '#{mixin + yaml_extension}'"
          @loginator.log( msg, Verbosity::ERRORS )
          validated = false
        end
      end
    end

    return validated
  end


  # Yield ordered list of filepaths
  def lookup_mixins(mixins:, load_paths:, yaml_extension:)
    _mixins = []

    # Already validated, so we know any mixin filepath or name is found in load_paths

    # Fill filepaths array with filepaths
    mixins.each do |mixin|
      # Handle explicit filepaths
      if @path_validator.filepath?( mixin )
        _mixins << mixin
        next # Success, move on in mixin iteration
      end

      # Look for mixin in load paths.
      # Move on in mixin iteration if mixin is found.
      next if load_paths.any? do |path|
        filepath = File.join( path, mixin + yaml_extension )
        exist = @file_wrapper.exist?( filepath )
        _mixins << filepath if exist
        exist
      end

      # Finally, fall through to simply add the unmodified name to the list.
      # validate_mixins() should have already confirmed it exists in load_paths.
      _mixins << mixin
    end

    return _mixins
  end

end
