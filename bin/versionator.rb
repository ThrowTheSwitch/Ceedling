# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'exceptions'
require 'constants'  # Filename constants
require 'version'    # Import Ceedling constant symbols from lib/version.rb

## Definitions
##  TAG: <#.#.#> version string used to package the software bundle
##  BUILD: TAG combined with git commit hash (<#.#.#>-<SHA>)

class Versionator

  attr_reader :ceedling_tag, :ceedling_build, :ceedling_install_path
  attr_reader :unity_tag, :cmock_tag, :cexception_tag

  def initialize(ceedling_root_path, ceedling_vendor_path=nil)

    ##
    ## Ceedling version info
    ##

    @ceedling_install_path = ceedling_root_path.clone()
    ceedling_git_sha = nil

    # Set Ceedling tag
    @ceedling_tag = Ceedling::Version::TAG

    # Create Ceedling build string
    # Lookup the Ceedling Git commit SHA if it exists as simple text file in the root of the codebase
    ceedling_commit_sha_filepath = File.join( ceedling_root_path, GIT_COMMIT_SHA_FILENAME )
    @ceedling_build = 
      if File.exist?( ceedling_commit_sha_filepath )
        # Ingest text from commit SHA file and clean it up
        sha = File.read( ceedling_commit_sha_filepath ).strip()
        # <TAG>-<SHA>
        "#{@ceedling_tag}-#{sha}"
      else
        # <TAG>
        @ceedling_tag
      end

    ##
    ## Build frameworks version info
    ##

    # Do no framework version gathering if it's not asked for
    return if ceedling_vendor_path.nil?

    # Create _tag accessors in the Versionator object

    # Anonymous hash to iterate through complementary vendor projects
    { 'UNITY'      => File.join( 'unity', 'src', 'unity.h' ),
      'CMOCK'      => File.join( 'cmock', 'src', 'cmock.h' ),
      'CEXCEPTION' => File.join( 'c_exception', 'lib', 'CException.h' )
    }.each_pair do |name, path|
      filename = File.join( ceedling_vendor_path, path )

      # Actually look up the vendor project version number components
      version = [0,0,0]

      begin
        File.readlines( filename ).each do |line|
          ['VERSION_MAJOR', 'VERSION_MINOR', 'VERSION_BUILD'].each_with_index do |field, i|
            m = line.match(/#{name}_#{field}\s+(\d+)/)
            version[i] = m[1] unless (m.nil?)
          end
        end
      rescue
        raise CeedlingException.new( "Could not collect version information for vendor component: #{filename}" )
      end

      # Splat version and evaluate it to create Versionator object accessor
      eval("@#{name.downcase}_tag = '#{version.join(".")}'")
    end
  end
end
