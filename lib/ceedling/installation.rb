# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rbconfig'

# One Ceedling installation, identified by its root directory. Its version is read
# from its own files, never from the constants of whichever installation loaded first.
#
# An application loaded by an older launcher reaches this file through require_relative
# with someone else's code already loaded, so it depends on nothing else in lib/.
class Installation

  VERSION_FILE = File.join( 'lib', 'version.rb' )
  BUILTIN_MIXINS_DIR = File.join( 'vendor', 'unity', 'test', 'targets' )

  attr_reader :root

  def self.windows?
    return (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|msys|ucrt/i) ? true : false
  end

  def initialize(root)
    @root = File.expand_path( root )
  end

  def bin_path
    return File.join( @root, 'bin', 'ceedling' )
  end

  def rakefile_path
    return File.join( @root, 'lib', 'ceedling', 'rakefile.rb' )
  end

  # The version tag, or nil when this installation's lib/version.rb is missing or unreadable
  def version
    @version = read_version() unless defined?( @version )
    return @version
  end

  # True when this installation's launcher validates a built-in mixin directory the
  # installation does not hold. `--local` vendoring left it out from 1.1.0 through 1.2.1,
  # so such a copy fails on its own and only ever ran inside another launcher's process.
  def missing_builtin_mixins?
    mixins_filepath = File.join( @root, 'bin', 'mixins.rb' )
    return false if !File.exist?( mixins_filepath )
    return false if !File.read( mixins_filepath ).include?( 'BUILTIN_MIXIN_LOAD_PATHS' )

    return !File.directory?( File.join( @root, BUILTIN_MIXINS_DIR ) )
  end

  # Symlinks resolve, and Windows paths compare without case
  def ==(other)
    return false unless other.is_a?( Installation )
    return Installation.windows? ? identity.casecmp?( other.identity ) : (identity == other.identity)
  end

  # "Ceedling 1.2.0", or without the version when it cannot be read
  def name(noun='Ceedling')
    return [noun, version()].compact.join( ' ' )
  end

  # "Ceedling 1.2.0 at /path/", or without the version when it cannot be read
  def describe(noun='Ceedling')
    return "#{name( noun )} at #{@root}/"
  end

  protected

  def identity
    return File.realpath( @root )
  rescue SystemCallError
    return @root
  end

  private

  # lib/version.rb defines Ceedling::Version. Evaluated within an anonymous module, its
  # constants land beneath that module instead of reopening the loaded ::Ceedling.
  def read_version
    filepath = File.join( @root, VERSION_FILE )
    sandbox = Module.new
    sandbox.module_eval( File.read( filepath ), filepath )
    return sandbox.const_get( :Ceedling, false ).const_get( :Version, false ).const_get( :TAG, false )
  rescue StandardError, ScriptError
    return nil
  end

end
