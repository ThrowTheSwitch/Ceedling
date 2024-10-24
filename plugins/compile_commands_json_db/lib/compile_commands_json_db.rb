# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/constants'
require 'json'

class CompileCommandsJsonDb < Plugin
  
  # `Plugin` setup()
  def setup
    @fullpath = File.join(PROJECT_BUILD_ARTIFACTS_ROOT, "compile_commands.json")
    
    @database = []
    
    if (File.exist?(@fullpath) && File.size(@fullpath) > 0)
      @database = JSON.parse( File.read(@fullpath) )
    end

    @mutex = Mutex.new()
  end

  # `Plugin` build step hook
  def post_compile_execute(arg_hash)

    # Create new Entry from compilation
    value = {
      "directory" => Dir.pwd, # TODO: Replace with Ceedling project root when it exists
      "file" => arg_hash[:source],
      "command" => arg_hash[:shell_command],
      "output" => arg_hash[:object]
    }

    @mutex.synchronize do
      # Determine if we're updating an existing file description or adding a new one
      index = @database.index {|h| h["file"] == arg_hash[:source]}
      if index
        @database[index] = value
      else
        @database << value
      end

      # Rewrite the compile_commands.json file
      File.open(@fullpath,'w') {|f| f << JSON.pretty_generate(@database)}
    end
  end
end
