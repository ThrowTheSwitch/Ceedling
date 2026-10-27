# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/installation'

# Decides which Ceedling installation runs a command, and points app_cfg's paths at it
class InstallationSelector

  VENDOR_PATH = 'vendor/ceedling'

  constructor :file_wrapper, :config_walkinator, :path_validator, :loginator

  # Precedence:
  #  1. The WHICH_CEEDLING environment variable
  #  2. :project ↳ :which_ceedling in the configuration
  #  3. A vendor/ceedling/ directory in the working directory, unless detect_vendor is off
  #  4. The launcher's own installation
  # Each is a path to an installation or `gem`, meaning the launcher's own.
  def select(env:, app_cfg:, config: {}, detect_vendor: true)
    which = from_environment( env ) || from_config( config )
    which ||= from_vendor_directory() if detect_vendor

    if which.nil? or which.casecmp?( 'gem' )
      @loginator.log( " > Defaulting to running Ceedling from Gem", Verbosity::OBNOXIOUS ) if which.nil?
      return use( app_cfg[:launcher_root_path], app_cfg )
    end

    return use( validate( which ), app_cfg )
  end

  private

  def from_environment(env)
    return nil if env['WHICH_CEEDLING'].nil?

    @loginator.console( " > Set which Ceedling using environment variable WHICH_CEEDLING" )
    return env['WHICH_CEEDLING'].strip()
  end

  def from_config(config)
    value, _ = @config_walkinator.fetch_value( :project, :which_ceedling, hash:config )
    return nil if value.nil?

    @loginator.lazy( Verbosity::OBNOXIOUS ) { " > Set which Ceedling from config :project ↳ :which_ceedling => #{value.strip()}" }
    return value.strip()
  end

  def from_vendor_directory()
    return nil if !@file_wrapper.directory?( VENDOR_PATH )

    @loginator.log( " > Set which Ceedling to be vendored installation", Verbosity::OBNOXIOUS )
    return VENDOR_PATH
  end

  # Returns the standardized path of an installation, raising if it holds none
  def validate(which)
    path = @path_validator.standardize_paths( which ).first
    if !@file_wrapper.directory?( path )
      raise "Configured Ceedling launch path #{path}/ does not exist"
    end

    if !@file_wrapper.exist?( Installation.new( path ).rakefile_path )
      raise "Configured Ceedling launch path #{path}/ contains no Ceedling installation"
    end

    return path
  end

  def use(root, app_cfg)
    app_cfg.set_paths( root )
    @loginator.log( " > Launching Ceedling from #{app_cfg[:ceedling_root_path]}/", Verbosity::OBNOXIOUS )

    return Installation.new( root )
  end

end
