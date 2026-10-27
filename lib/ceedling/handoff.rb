# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rbconfig'
require_relative 'installation'

# The protocol by which one Ceedling installation hands a command off to another: the
# selected installation's own launcher replaces this process, given the original command
# line. Environment markers tell that process who launched it and stop it handing off again.
#
# Like Installation, this file depends on nothing else in lib/, so an application loaded
# by an older launcher can load it with require_relative.
module Handoff

  LAUNCHER_VAR = 'CEEDLING_HANDOFF_LAUNCHER'
  TARGET_VAR   = 'CEEDLING_HANDOFF_TARGET'

  # Removes the markers from env, so no subprocess of this build inherits them, and
  # returns them, or nil when no launcher handed off to this process
  def self.take_markers(env)
    launcher = env.delete( LAUNCHER_VAR )
    target = env.delete( TARGET_VAR )
    return nil if target.nil?

    return {launcher: launcher, target: target}
  end

  # Whether the markers name own as the installation a launcher handed off to
  def self.received?(markers, own:)
    return false if markers.nil? or markers[:target].nil?

    return Installation.new( markers[:target] ) == own
  end

  def self.handing_off_message(launcher:, target:)
    return "#{launcher.describe( 'Ceedling launcher' )} is handing off to #{target.describe()}, which runs in its own process."
  end

  def self.received_message(markers, own:)
    return "#{own.describe()} is now running, launched from #{Installation.new( markers[:launcher] ).describe()}."
  end

  # Replaces this process with target's own launcher. Nothing after this call runs, not
  # even END blocks, so logging drains and the standard streams flush first.
  def self.exec(target:, launcher:, argv:, loginator:)
    loginator.wrapup()
    $stdout.flush()
    $stderr.flush()

    markers = {LAUNCHER_VAR => launcher.root, TARGET_VAR => target.root}
    replace_process( markers, RbConfig.ruby, target.bin_path, *argv )
  end

  # Finishes a hand-off that a launcher before 1.2.2 cannot make: it loads this application
  # into its own process. Every such launcher kept the original command line in the
  # SystemWrapper it hands over, so the application restarts as its own launcher. Without
  # that command line, or inside a hand-off already, it warns and continues in-process,
  # so a restart never cycles.
  def self.complete_in_process(app_root:, app_cfg:, handoff_objects:, env:)
    launcher = Installation.new( launcher_root_of( app_cfg ) )
    app = Installation.new( app_root )
    return if launcher == app

    loginator = handoff_objects[:loginator]
    argv = command_line( handoff_objects[:system_wrapper] )
    restart = !(argv.nil? or in_handoff?( app_cfg, env ))

    loginator.log( loaded_message( launcher, app, restart ), Verbosity::COMPLAIN )
    exec( target:app, launcher:launcher, argv:argv, loginator:loginator ) if restart
  end

  # The one seam to the operating system, so specs can stand in for it
  def self.replace_process(env, *command)
    Kernel.exec( env, *command )
  end

  # The launcher's CeedlingAppConfig is defined in its own bin/
  def self.launcher_root_of(app_cfg)
    filepath, _ = app_cfg.class.instance_method( :initialize ).source_location
    return File.expand_path( '..', File.dirname( filepath ) )
  end

  def self.command_line(system_wrapper)
    return nil if !system_wrapper.respond_to?( :get_cmdline )

    return system_wrapper.get_cmdline()
  end

  def self.in_handoff?(app_cfg, env)
    return true if !app_cfg[:handoff].nil?

    return !(env[TARGET_VAR].nil? and env[LAUNCHER_VAR].nil?)
  end

  def self.loaded_message(launcher, app, restart)
    loaded = "#{launcher.describe( 'Ceedling launcher' )} loaded #{app.describe()} into its own process."
    return "#{loaded} Restarting in #{app.name()}'s own process. Upgrade Ceedling and review your installations to avoid this." if restart

    return "#{loaded} #{continuing_advice( app )}"
  end

  def self.continuing_advice(app)
    return "Continuing in the launcher's process, which can fail or misbehave. Upgrade Ceedling, or run this " +
           "installation's own launcher directly with `ruby #{display_path( app.bin_path )}`. A project created " +
           "with `--local` has a launch script at its root that does this: run `./ceedling` from the project root " +
           "(`.\\ceedling.cmd` on Windows)."
  end

  # Relative to the working directory when beneath it, as a user would type it
  def self.display_path(filepath)
    cwd = File.join( Dir.pwd, '' )
    return filepath.start_with?( cwd ) ? filepath.delete_prefix( cwd ) : filepath
  end

  private_class_method :launcher_root_of, :command_line, :in_handoff?, :loaded_message, :continuing_advice, :display_path

end
