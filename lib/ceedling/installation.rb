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

  # Symlinks resolve, and Windows paths compare without case
  def ==(other)
    return false unless other.is_a?( Installation )
    return Installation.windows? ? identity.casecmp?( other.identity ) : (identity == other.identity)
  end

  # "Ceedling 1.2.0 at /path/", or without the version when it cannot be read
  def describe(noun='Ceedling')
    return [noun, version(), "at #{@root}/"].compact.join( ' ' )
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
