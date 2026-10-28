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

    # Configured load paths are higher in search path ordering
    load_paths = _mixins[:load_paths] || []
    enabled    = (_mixins[:enabled] || []).clone # A copy of the configuration section

    # Command line and environment variable mixin paths are standardized elsewhere, so
    # :mixins section paths are too, after any inline Ruby string expansion
    prepare_in_place( load_paths, ":mixins ↳ :load_paths" )
    prepare_in_place( enabled, ":mixins ↳ :enabled" )

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
    return mixins.map { |mixin| mixin_found?( mixin, load_paths, source, yaml_extensions ) }.all?
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

  # Expands and standardizes each of `paths`, keeping each String the configuration holds
  def prepare_in_place(paths, source)
    paths.each { |path| path.replace( @path_validator.standardize_paths( @ruby_expandinator.expand( path, source: source ) ).first ) }
  end

  # A mixin filepath must exist, and a mixin name must be found in the load paths
  def mixin_found?(mixin, load_paths, source, yaml_extensions)
    if @path_validator.filepath?( mixin )
      return true if @file_wrapper.exist?( mixin )

      @loginator.log( "Cannot find mixin at #{mixin}", Verbosity::ERRORS )
      return false
    end
    return true unless mixin_filepath( mixin, load_paths, yaml_extensions ).nil?

    filenames = yaml_extensions.map { |extension| "'#{mixin}#{extension}'" }.join( ' or ' )
    @loginator.log( "#{source} '#{mixin}' cannot be found in mixin load paths as #{filenames}", Verbosity::ERRORS )
    return false
  end

  # The first existing file named for the mixin, searching each load path in turn for each
  # extension
  def mixin_filepath(mixin, load_paths, yaml_extensions)
    candidates = load_paths.product( yaml_extensions ).map { |path, extension| File.join( path, mixin + extension ) }
    return candidates.find { |filepath| @file_wrapper.exist?( filepath ) }
  end

end
