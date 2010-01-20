# The path to the root directory of your application.
APP_ROOT = File.join(File.dirname(__FILE__), '..')

ADDITIONAL_LOAD_PATHS = []
ADDITIONAL_LOAD_PATHS.concat %w(
  lib 
).map { |dir| "#{APP_ROOT}/#{dir}" }.select { |dir| File.directory?(dir) }

# Prepend to $LOAD_PATH
ADDITIONAL_LOAD_PATHS.reverse.each { |dir| $:.unshift(dir) if File.directory?(dir) }

# Require any additional libraries needed
