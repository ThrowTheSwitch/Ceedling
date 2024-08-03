# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

#
# version.rb is run:
#  - As a script to produce a Ceedling version number used in the release build process
#  - As a module of version constants consumed by Ceedling's command line version output
#  - As a module of version constants consumed by Ceedling’s gem building process

module Ceedling
  module Version
    GEM = '1.0.0'
    CEEDLING_TAG = GEM

    project_root = File.join( File.dirname( __FILE__ ), '../..' )

    # If this file (version.rb) is loaded, we know it is next to the vendor path to use for version lookups
    vendor_path = File.expand_path( File.join( project_root, 'vendor' ) )

    # Set the constant for Git SHA if it exists as simple text file in the root of the codebase
    commit_sha_filepath = File.join( project_root, 'GIT_COMMIT_SHA' )
    CEEDLING_GIT_SHA = (File.exist?( commit_sha_filepath ) ? File.read( commit_sha_filepath ).strip() : nil)

    # Anonymous hash
    { 'UNITY'      => File.join( 'unity', 'src', 'unity.h' ),
      'CMOCK'      => File.join( 'cmock', 'src', 'cmock.h' ),
      'CEXCEPTION' => File.join( 'c_exception', 'lib', 'CException.h' )
    }.each_pair do |name, path|
      filename = File.join( vendor_path, path )

      # Actually look up the version number components
      a = [0,0,0]

      begin
        File.readlines( filename ).each do |line|
          ['VERSION_MAJOR', 'VERSION_MINOR', 'VERSION_BUILD'].each_with_index do |field, i|
            m = line.match(/#{name}_#{field}\s+(\d+)/)
            a[i] = m[1] unless (m.nil?)
          end
        end
      rescue
        raise( "Could not collect version information for vendor component: #{filename}" )
      end

      # Splat it to crete the final constant
      eval("#{name}_TAG = '#{a.join(".")}'")
    end

    # If run as a script, end with printing Ceedling’s version to $stdout
    puts CEEDLING_TAG if (__FILE__ == $0)
  end
end
