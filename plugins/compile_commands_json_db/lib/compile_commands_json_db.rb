# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/constants'
require 'json'

# Maintains a JSON compilation database so tools like clangd can see how a build compiles.
#
# The database accumulates across builds. A delta build compiles only what changed, so
# entries from earlier builds carry over. It holds one entry per source file, and the
# latest compile of a file replaces any earlier one. Entries collect as compiles finish and
# are written once, when the build ends or fails.
class CompileCommandsJsonDb < Plugin

  # `Plugin` setup()
  def setup
    @file_wrapper = @ceedling[:file_wrapper]
    @loginator    = @ceedling[:loginator]
    @fullpath     = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, 'compile_commands.json' )
    # Hash: source filepath => entry, in the order sources were first compiled
    @database     = load_database()
    @changed      = false
    @mutex        = Mutex.new
  end

  # `Plugin` build step hook
  def post_compile_execute(arg_hash)
    entry = CompileCommandsJsonDb.entry_from( arg_hash )

    @mutex.synchronize do
      @database[entry['file']] = entry
      @changed = true
    end
  end

  # `Plugin` build step hooks -- a failed build still records what it compiled
  def post_build(_timestamp_s)
    write_database()
  end

  def post_error(_timestamp_s)
    write_database()
  end

  # The database entry for one compile.
  #
  # Commands use paths relative to Ceedling's working directory, so that is the entry's
  # directory. A source compiled from an isolated copy names that throwaway copy in its
  # command, so the command is rewritten to name the original source it stands for.
  def self.entry_from(arg_hash)
    source  = arg_hash[:source]
    command = arg_hash[:shell_command]
    copy    = arg_hash[:compile_source]
    command = command.gsub( copy ) { source } if copy

    return { 'directory' => Dir.pwd, 'file' => source, 'command' => command, 'output' => arg_hash[:object] }
  end

  ### Private

  private

  # A damaged database would otherwise fail every later build. Anything other than a list
  # is discarded and the database starts fresh. A list keeps only its entry objects.
  def load_database()
    return {} unless @file_wrapper.exist?( @fullpath )

    database = JSON.parse( @file_wrapper.read( @fullpath ) )
    return discard_database( 'is not a list of compile entries' ) unless database.is_a?( Array )

    return database.grep( Hash ).to_h { |entry| [entry['file'], entry] }
  rescue JSON::ParserError
    discard_database( 'is not valid JSON' )
  end

  def discard_database(reason)
    @loginator.log( "#{@fullpath} #{reason} ➡️ Starting a new compile_commands.json.", Verbosity::COMPLAIN, LogLabels::NOTICE )
    return {}
  end

  # Nothing is written when nothing compiled, which leaves an earlier build's file as it was
  def write_database()
    @mutex.synchronize do
      return unless @changed

      @file_wrapper.write( @fullpath, JSON.pretty_generate( @database.values ) )
      @changed = false
    end
  end

end
