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
  def validate_mixins(mixins:, load_paths:, source:, yaml_extensions:)
    validated = true

    mixins.each do |mixin|
      # Validate mixin filepaths
      if @path_validator.filepath?( mixin )
        if !@file_wrapper.exist?( mixin )
          @loginator.log( "Cannot find mixin at #{mixin}", Verbosity::ERRORS )
          validated = false
        end

      # Otherwise, validate that mixin name can be found in load paths
      elsif mixin_filepath( mixin, load_paths, yaml_extensions ).nil?
        filenames = yaml_extensions.map { |extension| "'#{mixin}#{extension}'" }.join( ' or ' )
        @loginator.log( "#{source} '#{mixin}' cannot be found in mixin load paths as #{filenames}", Verbosity::ERRORS )
        validated = false
      end
    end

    return validated
  end


  # Yield ordered list of filepaths
  def lookup_mixins(mixins:, load_paths:, yaml_extensions:)
    _mixins = []

    # Already validated, so we know any mixin filepath or name is found in load_paths

    # Fill filepaths array with filepaths
    mixins.each do |mixin|
      # Handle explicit filepaths
      if @path_validator.filepath?( mixin )
        _mixins << mixin
        next # Success, move on in mixin iteration
      end

      # Look for mixin in load paths. Failing that, add the unmodified name to the list.
      # validate_mixins() should have already confirmed it exists in load_paths.
      _mixins << (mixin_filepath( mixin, load_paths, yaml_extensions ) || mixin)
    end

    return _mixins
  end

  ### Private ###

  private

  # The first existing file named for the mixin, searching each load path in turn for each
  # extension
  def mixin_filepath(mixin, load_paths, yaml_extensions)
    candidates = load_paths.product( yaml_extensions ).map { |path, extension| File.join( path, mixin + extension ) }
    return candidates.find { |filepath| @file_wrapper.exist?( filepath ) }
  end

end
