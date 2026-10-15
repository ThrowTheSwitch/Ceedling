# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The commands that fetch and build one dependency, in the order they run.
#
# Fetching uses the plugin's configurable tools (:deps_zip, :deps_git_clone, and the
# rest), filling in each tool's arguments from the dependency's fetch settings. Custom
# fetch commands and build commands are command lines the user wrote. Each becomes a tool
# whose executable is its first word and whose arguments are the rest exactly as written,
# so quoting and spacing reach the shell unchanged. A built-in build step such as
# :build_lib stays a symbol for the plugin to carry out.
#
# `builder` makes a runnable command from a tool and its arguments, as
# ToolExecutor#build_command_line does.
class DependencyCommands

  def initialize(tools:, builder:)
    @tools   = tools
    @builder = builder
  end

  def fetch(spec)
    fetch = spec.fetch

    case spec.fetch_method
    when :zip      then [command( :zip, fetch[:source] )]
    when :tar_gzip then [command( :tar_gzip, fetch[:source] )]
    when :git      then git( fetch )
    when :svn      then [command( :subversion, option( '--revision', fetch[:revision] ), fetch[:source] )]
    when :custom   then custom( fetch[:executable] )
    else []
    end
  end

  def build(spec)
    return spec.build_steps.map { |step| step.is_a?( Symbol ) ? step : written( step ) }
  end

  private

  def command(tool, *args)
    return @builder.call( @tools.fetch( tool ), *args )
  end

  # A shallow clone, or a full clone and checkout when a commit hash is wanted
  def git(fetch)
    branch = option( '-b', fetch[:tag] || fetch[:branch] )
    return [command( :git_clone, branch, '--depth 1', fetch[:source] )] if fetch[:hash].nil?

    return [command( :git_clone, branch, '', fetch[:source] ), command( :git_checkout, fetch[:hash] )]
  end

  # Custom commands, one or a list, each named for its place in the list
  def custom(lines)
    return Array( lines ).map.with_index( 1 ) { |line, index| written( line, "Dependencies custom command ##{index}" ) }
  end

  def option(flag, value)
    return value.to_s.empty? ? '' : "#{flag} #{value}"
  end

  # A command line as written: its first word runs, and the rest passes through untouched
  def written(line, name = nil)
    executable, arguments = line.strip.split( /\s+/, 2 )
    return @builder.call( { name: name || executable, executable: executable, arguments: Array( arguments ) } )
  end

end
