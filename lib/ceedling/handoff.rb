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

  # The one seam to the operating system, so specs can stand in for it
  def self.replace_process(env, *command)
    Kernel.exec( env, *command )
  end

end
