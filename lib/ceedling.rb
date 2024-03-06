##
# This module defines the interface for interacting with and loading a project
# with Ceedling.
module Ceedling
  ##
  # Returns the location where the gem is installed.
  # === Return
  # _String_ - The location where the gem lives.
  def self.location
    # Ensure parent path traversal is expanded away
    File.absolute_path( File.join( File.dirname(__FILE__), '..') )
  end

  ##
  # Return the path to the "built-in" plugins.
  # === Return
  # _String_ - The path where the default plugins live.
  def self.plugins_load_path
    File.join( self.location, 'plugins')
  end

  ##
  # Return the path to the Ceedling Rakefile
  # === Return
  # _String_
  def self.rakefile
    File.join( self.location, 'lib', 'ceedling', 'rakefile.rb' )
  end

  def self.load_ceedling_rakefile()
    load "#{self.rakefile}"
  end

end

