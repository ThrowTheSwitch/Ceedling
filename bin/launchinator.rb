# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/installation'
require 'ceedling/handoff'

# Runs each command in the installation it selects. Another installation's own launcher
# replaces this process. The launcher's own installation continues here.
class Launchinator

  constructor :installation_selector, :loginator

  # Selects which Ceedling runs a command and points app_cfg's paths at it, without handing off
  def resolve(env:, app_cfg:, config: {}, detect_vendor: true)
    return @installation_selector.select( env:env, config:config, app_cfg:app_cfg, detect_vendor:detect_vendor )
  end

  # Hands off to another selected installation and never returns. Otherwise returns the
  # rakefile to load in this process. A process a launcher already handed off to says so
  # and never hands off again.
  def launch(env:, app_cfg:, config: {}, detect_vendor: true)
    target = resolve( env:env, app_cfg:app_cfg, config:config, detect_vendor:detect_vendor )
    launcher = Installation.new( app_cfg[:launcher_root_path] )

    if Handoff.received?( app_cfg[:handoff], own:launcher )
      @loginator.log( Handoff.received_message( app_cfg[:handoff], own:launcher ), Verbosity::COMPLAIN, LogLabels::NOTICE )
    elsif target != launcher
      hand_off( target, launcher, app_cfg[:argv] )
    end

    return target.rakefile_path
  end

  private

  def hand_off(target, launcher, argv)
    validate_runnable( target )

    @loginator.log( Handoff.handing_off_message( launcher:launcher, target:target ), Verbosity::COMPLAIN, LogLabels::NOTICE )
    Handoff.exec( target:target, launcher:launcher, argv:argv, loginator:@loginator )
  end

  # An installation that cannot run on its own would fail in a way that hides why
  def validate_runnable(target)
    if !File.exist?( target.bin_path )
      raise CeedlingException.new( "Cannot hand off to #{target.describe()}: it has no launcher at #{target.bin_path}" )
    end

    return if !target.missing_builtin_mixins?

    raise CeedlingException.new(
      "#{target.describe()} cannot run on its own: it lacks #{Installation::BUILTIN_MIXINS_DIR}/, which `--local` " +
      "vendoring left out from Ceedling 1.1.0 through 1.2.1. Re-vendor it with `ceedling upgrade <project path>`, " +
      "then run this command again."
    )
  end

end
