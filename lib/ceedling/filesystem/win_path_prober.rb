# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/win_long_paths'
require 'ceedling/filesystem/win_path_limit'

# Decides once per process whether Windows long paths are in effect for a
# `:project` ↳ `:win_path_limit` mode, and says why in one message.
#
# FileWrapper asks only on Windows, with `:auto` or `:long_paths`, once a path first nears
# the classic limit. The probe works below the build root, and reads the registry through
# the `:tools` ↳ `:windows_registry_query` tool, which configuration adds in exactly that
# case. Compile and test threads can ask at once, so the probe runs under a lock.
class WinPathProber

  constructor :configurator, :tool_executor, :loginator

  def setup
    @lock       = Mutex.new
    @long_paths = nil
  end

  # Whether long paths are in effect. The first call probes and logs the decision; later
  # calls return the same answer.
  def long_paths?(mode)
    @lock.synchronize do
      next @long_paths unless @long_paths.nil?

      result   = WinLongPaths.probe( @configurator.project_build_root, query: method( :registry_query ) )
      decision = WinPathLimit.decision( result, mode )
      @loginator.log( *decision[:log] )
      @long_paths = decision[:long_paths]
    end
  end

  # `reg query` output for the long paths value, and whether the query succeeded. A failed
  # exit is an answer, not an error, so the tool runs without raising on one.
  def registry_query
    command = @tool_executor.build_command_line(
      @configurator.tools_windows_registry_query, [], WinLongPaths::REGISTRY_KEY, WinLongPaths::REGISTRY_VALUE
    )
    command[:options][:boom] = false
    result = @tool_executor.exec( command )

    return [result[:output], !@tool_executor.failed?( result )]
  end

end
